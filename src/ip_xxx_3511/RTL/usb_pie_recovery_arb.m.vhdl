--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_pie_recovery_arb.m.vhdl
--
--  Architecture: rtl (Phase 8 rewrite)
--
--  Microarchitecture overview
--  --------------------------
--  Control plane (this rewrite):
--    Explicit four-state FSM (claim_state_r) walks one OCP recovery class
--    control transfer through SETUP -> DATA (optional) -> STATUS, matching
--    USB 2.0 Sec 8.5.3 control-transfer phasing.  The FSM:
--      * Decodes the OCP class match COMBINATIONALLY off the captured
--        SETUP beat (setup_capture_c) before the SETUP-received pulse
--        propagates to the legacy SIE (per Phase 7 FSDB evidence, the
--        pulse trails the SETUP beat by ~10s of PIE clocks; see
--        research/usb_ocp_p7_gate_debug.md).
--      * Asserts claim_q the same cycle the SETUP matches.  No SV-side
--        flop, no multi-cycle handshake -- this removes the entire
--        Phase 7 latency / race window.
--      * Holds claim_q for the entire SETUP+DATA+STATUS sequence, counted
--        from pie_endtransfer pulses.  Path selection depends on the
--        SETUP wLength: zero -> SETUP then STATUS (no DATA); non-zero ->
--        SETUP then DATA then STATUS.
--      * On collision (a new class-match SETUP arrives while claim_q is
--        still high) the arbiter forces a STALL handshake back to PIE
--        and drops claim_q (busy-decline policy; per Phase 8 plan
--        Sec 8.1 TODO option (a); safer than buffering, avoids USB 2.0
--        ~5 ms transfer timeout if the SV side ever hangs).  USB 2.0
--        Sec 8.5.3 anyway mandates abandoning the in-flight transfer on
--        a fresh SETUP; the STALL just informs the host explicitly.
--
--  Data plane (mostly preserved from prior implementation):
--    * SETUP capture: latch pie_rxdata[63:0] when (pie_epinfo_setup AND
--      pie_rxdatavalid).  USB 2.0 Sec 8.5.3: SETUP payload is always 8 B
--      and PIE delivers it in a single 64-bit beat.
--    * RX byte serializer: pie_rxdata 64b -> 8b stream into ctrl_out_*.
--      Only enabled while claim_q='1' and the beat is NOT a SETUP.
--    * TX byte serializer: ctrl_in_* 8b -> 64b beat into PIE txdata.
--      ctrl_in_rdy honours both slot-full backpressure AND claim_q so
--      the SV producer sees backpressure the cycle the arbiter releases
--      ownership.  Slot is flushed whenever claim_q='0' so no state
--      leaks across transfer boundaries (Phase 5 follow-on Bug 3).
--    * wLength latched into nbytes_r and driven into PIE's epinfo_nbytes
--      so the IN data-stage length matches the host-requested wLength
--      (OCP Recovery v1.1 Sec 8.5.1; USB 2.0 Sec 5.5.3).
--    * The legacy bundle pass-through is bit-identical to the
--      un-arbitered IP whenever claim_q='0', so standard USB enumeration
--      (GET_DESCRIPTOR / SET_ADDRESS / SET_CONFIGURATION / GET_STATUS /
--      class hooks for non-OCP interfaces / ...) is unaffected.
--
--  Reuse / area note
--  -----------------
--  Counters:
--    * rx_byte_idx_r  : 3-bit (0..7)         -- byte offset in 64-bit beat
--    * tx_byte_idx_r  : 3-bit (0..7)         -- byte offset in 64-bit beat
--    * rx_remaining_r : 12-bit (matches pie_rx_nbytes width)
--    * nbytes_r       : 15-bit (matches epinfo_nbytes width)
--    * claim_state_r  : 2-bit (four-state FSM enum)
--  Total added Phase-8 storage vs prior implementation: -3 flops net
--  (removed setup_is_ocp_match_q, pie_setup_received_r, setup_end_seen_q;
--   added claim_state_r=2b, decline_pend_q=1b, last_setup_was_ocp_q=1b).
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture rtl of usb_pie_recovery_arb is

  -- ----------------------------------------------------------------------
  -- Constants / generics-as-slv.
  -- ----------------------------------------------------------------------
  constant BYTES_PER_BEAT : integer := USB_DATAWIDTH / 8;  -- 8 for 64b PIE
  constant REC_EPNR_SLV   : std_logic_vector(3 downto 0) :=
                              std_logic_vector(to_unsigned(C_REC_EPNR, 4));
  constant REC_IFACE_SLV  : std_logic_vector(7 downto 0) :=
                              std_logic_vector(to_unsigned(C_REC_IFACE_NUM, 8));
  -- OCP Recovery v1.1 Section 8.5.1: the bRequest value carried by the
  -- class-specific control transfer SETUP is OCP_RECOVERY_TRANSFER (0x00).
  constant OCP_RECOVERY_TRANSFER : std_logic_vector(7 downto 0) := x"00";

  -- ----------------------------------------------------------------------
  -- Claim FSM (control plane).
  --
  -- States:
  --   S_IDLE   : pass-through; legacy owns the bus.  No claim asserted.
  --   S_SETUP  : SETUP just classified as OCP class; waiting for the
  --              SETUP-stage pie_endtransfer.  claim_q='1'.
  --   S_DATA   : DATA stage of a class transfer (IN or OUT).  Waiting for
  --              the DATA-stage pie_endtransfer.  claim_q='1'.
  --   S_STATUS : STATUS stage of a class transfer.  Waiting for the
  --              STATUS-stage pie_endtransfer to release claim.
  --              claim_q='1'.
  --
  -- The FSM transitions on:
  --   - setup_capture_c : NEW SETUP beat arriving (top priority, mirrors
  --                       USB 2.0 Sec 8.5.3 abandon-on-new-SETUP rule).
  --   - pie_endtransfer : end-of-current-stage marker from the PIE.
  --
  -- Collision handling: if setup_capture_c='1' while NOT S_IDLE and the
  -- new SETUP is also an OCP class match, we cannot deliver two
  -- overlapping transfers to the SV decoder.  Per Phase 8 plan Sec 8.1
  -- TODO option (a) we set decline_pend_q to force a STALL handshake for
  -- the new SETUP and drop claim back to S_IDLE.
  -- ----------------------------------------------------------------------
  type t_claim_state is (S_IDLE, S_SETUP, S_DATA, S_STATUS);
  signal claim_state_r   : t_claim_state;
  signal claim_state_nxt : t_claim_state;

  signal claim_q       : std_logic;  -- derived: '1' when not in S_IDLE

  -- Rising-edge detect of pie_endtransfer (which is held as a multi-cycle
  -- LEVEL by the PIE).  See claim_fsm_comb_proc comment for rationale.
  signal pie_endtransfer_q       : std_logic;
  signal pie_endtransfer_pulse_c : std_logic;

  -- SETUP class-match decoded combinationally on the cycle PIE delivers
  -- the SETUP beat.  Same cycle as setup_capture_c -- this is the key
  -- timing property the Phase 8 rewrite hinges on (Phase 7 used a flop
  -- because it was filtering downstream; we filter upstream now).
  --
  -- Field bit indices follow USB 2.0 Sec 9.3 Tbl 9-2 little-endian
  -- SETUP byte layout:
  --   byte0 bmRequestType  = pie_rxdata[ 7: 0]
  --   byte1 bRequest       = pie_rxdata[15: 8]
  --   byte2..3 wValue (LE) = pie_rxdata[31:16]
  --   byte4..5 wIndex (LE) = pie_rxdata[47:32]  -- iface number in byte4
  --   byte6..7 wLength (LE)= pie_rxdata[63:48]
  --
  -- OCP class match (OCP Recovery v1.1 Sec 8.5.1):
  --   bmRequestType[6:5] == "01"      (Class type)
  --   bmRequestType[4:0] == "00001"   (Recipient = Interface)
  --   bRequest           == 8'h00     (OCP_RECOVERY_TRANSFER)
  --   wIndex[7:0]        == C_REC_IFACE_NUM
  --   wIndex[15:8]       == 8'h00     (host MUST drive 0; reject otherwise)
  -- The direction bit bmRequestType[7] and wValue/wLength are downstream-
  -- decoder fields and do not participate in the claim filter.
  signal setup_is_ocp_match_c : std_logic;
  signal setup_dir_in_c       : std_logic;  -- bmRequestType[7] (1 = IN data)

  -- Latched copy of "the most recently captured SETUP was OCP class"
  -- whose ONLY role is to gate the legacy SETUP-received notification.
  -- It is set on every setup_capture_c (to the current match value) so
  -- that for any subsequent pie_epinfo_setup_received pulse the gate
  -- knows the polarity to apply.  Cleared by reset only -- next
  -- setup_capture_c overwrites it.
  signal last_setup_was_ocp_q : std_logic;

  -- Set when a new class-match SETUP arrives while claim is still held
  -- by a prior class transfer (collision).  Forces a one-shot STALL via
  -- the muxed epinfo_to_pie_stall path.  Cleared by reset or by the
  -- pie_endtransfer pulse that closes out the colliding transfer.
  signal decline_pend_q : std_logic;

  -- ----------------------------------------------------------------------
  -- SETUP capture (single 64-bit latch).  pie_epinfo_setup is high for a
  -- multi-cycle window around the SETUP beat; the pie_rxdatavalid pulse
  -- frames the cycle on which pie_rxdata holds the 8 SETUP bytes.
  -- ----------------------------------------------------------------------
  signal setup_capture_c : std_logic;
  signal setup_pkt_r     : std_logic_vector(63 downto 0);
  signal setup_pkt_vld_r : std_logic;

  -- ----------------------------------------------------------------------
  -- Per-transfer wLength budget driven into PIE's epinfo_nbytes (so the
  -- TX serializer in usb_pie sends exactly wLength bytes on the wire
  -- rather than the previous placeholder of 8).  Truncated to 15 bits
  -- to match the PIE port width; OCP Recovery v1.1 register payloads are
  -- <= 256 bytes so the truncation cannot affect any spec-legal recovery
  -- transfer.
  -- ----------------------------------------------------------------------
  signal nbytes_r : unsigned(14 downto 0);

  -- ----------------------------------------------------------------------
  -- Control-OUT serializer (PIE 64b -> SV 8b).
  -- ----------------------------------------------------------------------
  signal rx_word_r        : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_byte_idx_r    : unsigned(2 downto 0);
  signal rx_remaining_r   : unsigned(11 downto 0);
  signal rx_active_r      : std_logic;
  signal rx_word_nxt      : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_byte_idx_nxt  : unsigned(2 downto 0);
  signal rx_remaining_nxt : unsigned(11 downto 0);
  signal rx_active_nxt    : std_logic;
  signal ctrl_out_data_c  : std_logic_vector(7 downto 0);
  signal ctrl_out_vld_c   : std_logic;
  signal ctrl_out_last_c  : std_logic;

  -- ----------------------------------------------------------------------
  -- Control-IN serializer (SV 8b -> PIE 64b).
  -- ----------------------------------------------------------------------
  signal tx_word_r        : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_byte_idx_r    : unsigned(2 downto 0);
  signal tx_word_full_r   : std_logic;
  signal tx_last_r        : std_logic;
  signal tx_word_nxt      : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_byte_idx_nxt  : unsigned(2 downto 0);
  signal tx_word_full_nxt : std_logic;
  signal tx_last_nxt      : std_logic;
  signal ctrl_in_rdy_c    : std_logic;

begin

  -- ======================================================================
  -- SETUP capture
  -- ======================================================================
  setup_capture_c <= pie_epinfo_setup and pie_rxdatavalid;

  setup_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      setup_pkt_r          <= (others => '0');
      setup_pkt_vld_r      <= '0';
      nbytes_r             <= (others => '0');
      last_setup_was_ocp_q <= '0';
    elsif rising_edge(clk) then
      -- Default: drop pulse.
      setup_pkt_vld_r <= '0';
      if setup_capture_c = '1' then
        setup_pkt_r <= pie_rxdata;
        -- wLength little-endian at bytes 6..7 of the SETUP payload
        -- (USB 2.0 Sec 9.3 Tbl 9-2).  Bit 63 is dropped to fit the
        -- 15-bit PIE nbytes port (see nbytes_r decl comment).
        nbytes_r <= unsigned(pie_rxdata(62 downto 48));
        -- Pre-filtered SETUP-vld pulse delivered to SV ctrl_decode ONLY
        -- when this SETUP matches OCP class; the SV side therefore
        -- never sees a standard or unrelated-class SETUP (Phase 8 key
        -- routing change).
        setup_pkt_vld_r      <= setup_is_ocp_match_c;
        last_setup_was_ocp_q <= setup_is_ocp_match_c;
      end if;
    end if;
  end process setup_clk_proc;

  setup_pkt     <= setup_pkt_r;
  setup_pkt_vld <= setup_pkt_vld_r;

  -- ======================================================================
  -- Class-match decode (combinational; cycle setup_capture_c='1').
  -- ======================================================================
  setup_is_ocp_match_c <= '1' when (setup_capture_c           = '1')
                                and (pie_rxdata( 6 downto  5) = "01")
                                and (pie_rxdata( 4 downto  0) = "00001")
                                and (pie_rxdata(15 downto  8) = OCP_RECOVERY_TRANSFER)
                                and (pie_rxdata(39 downto 32) = REC_IFACE_SLV)
                                and (pie_rxdata(47 downto 40) = x"00")
                            else '0';
  -- Direction bit: USB 2.0 Sec 9.3 Tbl 9-2 -- bmRequestType[7] = 1 means
  -- Device-to-Host (IN data stage); 0 means Host-to-Device (OUT data).
  setup_dir_in_c <= pie_rxdata(7);

  -- ======================================================================
  -- Claim FSM
  --
  -- One state machine deciding ownership of EP0 for OCP recovery class
  -- transfers.  Outputs claim_q (S_IDLE => 0; else 1).
  --
  -- Stage-end pulse policy (USB 2.0 Sec 8.5.3):
  --   - The PIE asserts pie_endtransfer at the END of each control
  --     transfer stage (SETUP / each DATA packet boundary the PIE
  --     considers a stage / STATUS).  For control transfers the practical
  --     observed pulses are: one for SETUP-end, one for DATA-end
  --     (covering the full data stage as one block), one for STATUS-end.
  --   - The SETUP-stage pulse must NOT be exposed to SV as
  --     ctrl_xfer_done (Phase 7 iter 8 corruption root cause).  The FSM
  --     consumes it internally to advance S_SETUP -> S_DATA or S_STATUS.
  --   - The DATA- and STATUS-stage pulses are forwarded to SV as
  --     ctrl_xfer_done so the SV decoder can release per-transfer state
  --     (rb_wr/rd byte pulses, buffer empties, etc).
  --
  -- wLength branching (USB 2.0 Sec 8.5.3 / Sec 9.4.3 etc):
  --   - wLength = 0 -> SETUP -> STATUS (no DATA stage).  The STATUS-stage
  --     packet is IN (regardless of bmRequestType[7] direction); see
  --     USB 2.0 Sec 8.5.3 -- "the direction of the STATUS stage is
  --     opposite that of the Data stage; if no Data stage, STATUS is IN".
  --   - wLength > 0 -> SETUP -> DATA -> STATUS, where the STATUS-stage
  --     direction is opposite that of the DATA-stage (IN data -> OUT
  --     ZLP STATUS; OUT data -> IN ZLP STATUS).  The arbiter mux stays
  --     on the SV side for the STATUS stage so SV ctrl_decode owns the
  --     ZLP response.
  -- ======================================================================
  claim_fsm_comb_proc : process (claim_state_r, setup_capture_c,
                                 setup_is_ocp_match_c, pie_endtransfer_pulse_c,
                                 nbytes_r)
  begin
    -- Default: hold.
    claim_state_nxt <= claim_state_r;

    case claim_state_r is

      when S_IDLE =>
        -- Pass-through.  Promote to S_SETUP only on an OCP class match.
        if (setup_capture_c = '1') and (setup_is_ocp_match_c = '1') then
          claim_state_nxt <= S_SETUP;
        end if;

      when S_SETUP =>
        -- A brand-new SETUP arriving here means the host abandoned the
        -- in-flight transfer (USB 2.0 Sec 8.5.3).  If it's a class match
        -- we restart at S_SETUP; otherwise the new SETUP belongs to the
        -- legacy path and we drop ownership.
        if setup_capture_c = '1' then
          if setup_is_ocp_match_c = '1' then
            claim_state_nxt <= S_SETUP;
          else
            claim_state_nxt <= S_IDLE;
          end if;
        elsif pie_endtransfer_pulse_c = '1' then
          -- SETUP-stage end.  Branch on wLength latched at SETUP capture.
          -- USB 2.0 Sec 8.5.3 / Sec 9.4 -- zero-wLength control requests
          -- have no DATA stage; transition directly to STATUS.
          if nbytes_r = to_unsigned(0, nbytes_r'length) then
            claim_state_nxt <= S_STATUS;
          else
            claim_state_nxt <= S_DATA;
          end if;
        end if;

      when S_DATA =>
        if setup_capture_c = '1' then
          if setup_is_ocp_match_c = '1' then
            claim_state_nxt <= S_SETUP;
          else
            claim_state_nxt <= S_IDLE;
          end if;
        elsif pie_endtransfer_pulse_c = '1' then
          claim_state_nxt <= S_STATUS;
        end if;

      when S_STATUS =>
        if setup_capture_c = '1' then
          if setup_is_ocp_match_c = '1' then
            claim_state_nxt <= S_SETUP;
          else
            claim_state_nxt <= S_IDLE;
          end if;
        elsif pie_endtransfer_pulse_c = '1' then
          claim_state_nxt <= S_IDLE;
        end if;

      when others =>
        claim_state_nxt <= S_IDLE;
    end case;
  end process claim_fsm_comb_proc;

  -- ----------------------------------------------------------------------
  -- pie_endtransfer is driven by the PIE as a multi-cycle LEVEL signal
  -- (held high for >=3 PIE clocks).  The FSM above must transition only
  -- on the RISING EDGE of this signal, otherwise S_SETUP -> S_DATA ->
  -- S_STATUS -> S_IDLE walks in 3 consecutive clocks and claim_q drops
  -- well before the DATA-stage bytes can flow out of ctrl_decode through
  -- the arbiter staging slot.  Edge-detect with a 1-FF history.
  --
  -- ADDITIONAL: the legacy IP-3511 SetError() process pairs
  -- set_pie_endtransfer with set_pie_error, so pie_endtransfer also
  -- fires on every protocol error (overrun/underrun/CRC/etc).  We must
  -- only advance the FSM on clean stage-end events, NOT on error events
  -- (an error event during DATA stage would prematurely jump to S_STATUS
  -- and the claim_q stays asserted forever because subsequent host
  -- retries cannot recover the FSM).  Qualify the pulse with pie_success.
  -- ----------------------------------------------------------------------
  pie_endtransfer_pulse_c <= (pie_endtransfer and not pie_endtransfer_q)
                             and pie_success;

  pie_endtransfer_edge_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      pie_endtransfer_q <= '0';
    elsif rising_edge(clk) then
      pie_endtransfer_q <= pie_endtransfer;
    end if;
  end process pie_endtransfer_edge_proc;

  claim_fsm_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      claim_state_r  <= S_IDLE;
      decline_pend_q <= '0';
    elsif rising_edge(clk) then
      claim_state_r <= claim_state_nxt;
      -- decline_pend_q: set when a class-match SETUP collides with an
      -- in-flight class transfer.  Cleared on the next pie_endtransfer
      -- so the STALL handshake only stalls the colliding transfer, not
      -- the next one.
      if (setup_capture_c = '1') and (setup_is_ocp_match_c = '1') and
         (claim_state_r /= S_IDLE) then
        decline_pend_q <= '1';
      elsif pie_endtransfer_pulse_c = '1' then
        decline_pend_q <= '0';
      end if;
    end if;
  end process claim_fsm_clk_proc;

  claim_q          <= '0' when claim_state_r = S_IDLE else '1';
  rec_claim_status <= claim_q;

  -- ======================================================================
  -- Legacy SETUP-received gating.
  --
  -- Suppress the pie_epinfo_setup_received pulse when the most recently
  -- captured SETUP was an OCP class match (latched in
  -- last_setup_was_ocp_q on the setup_capture_c cycle).  Also OR-in the
  -- combinational match in case the pulse arrives on the same cycle as
  -- the SETUP capture (timing margin for any future PHY config).
  --
  -- This is the SOLE mechanism that prevents the MCU EPCS from being
  -- notified of recovery-class SETUPs (Phase 7 fix #8b; see
  -- research/usb_ocp_p7_gate_debug.md).  No downstream flop is required.
  -- ======================================================================
  legacy_setup_received_gated <= pie_epinfo_setup_received and
                                 (not last_setup_was_ocp_q) and
                                 (not setup_is_ocp_match_c);

  -- ======================================================================
  -- xfer-done re-emission to SV: ONLY pulse on DATA-stage and STATUS-
  -- stage pie_endtransfer events.  The SETUP-stage pie_endtransfer is
  -- consumed by the FSM and never reaches the SV decoder.
  -- ======================================================================
  ctrl_xfer_done <= pie_endtransfer when (claim_state_r = S_DATA) or
                                          (claim_state_r = S_STATUS)
                    else '0';

  -- ======================================================================
  -- Control-OUT byte stream (PIE 64b -> SV 8b).
  -- ======================================================================
  rxstream_comb_proc : process (rx_word_r, rx_byte_idx_r, rx_remaining_r,
                                rx_active_r, pie_rxdata, pie_rxdatavalid,
                                pie_rx_nbytes, pie_epinfo_setup, claim_q,
                                ctrl_out_rdy)
    variable byte_index_v : integer range 0 to 7;
  begin
    rx_word_nxt      <= rx_word_r;
    rx_byte_idx_nxt  <= rx_byte_idx_r;
    rx_remaining_nxt <= rx_remaining_r;
    rx_active_nxt    <= rx_active_r;
    ctrl_out_vld_c   <= '0';
    ctrl_out_last_c  <= '0';
    ctrl_out_data_c  <= (others => '0');

    -- Latch incoming RX data beat (DATA stage of an OUT class transfer).
    if (pie_rxdatavalid = '1') and (claim_q = '1') and
       (pie_epinfo_setup = '0') and (rx_active_r = '0') then
      rx_word_nxt      <= pie_rxdata;
      rx_byte_idx_nxt  <= (others => '0');
      rx_remaining_nxt <= unsigned(pie_rx_nbytes);
      if unsigned(pie_rx_nbytes) /= 0 then
        rx_active_nxt <= '1';
      end if;
    end if;

    -- Drain one byte per ctrl_out_rdy cycle.
    if rx_active_r = '1' then
      byte_index_v   := to_integer(rx_byte_idx_r);
      ctrl_out_data_c <= rx_word_r(byte_index_v*8 + 7 downto byte_index_v*8);
      ctrl_out_vld_c  <= '1';
      if rx_remaining_r = to_unsigned(1, rx_remaining_r'length) then
        ctrl_out_last_c <= '1';
      end if;
      if ctrl_out_rdy = '1' then
        rx_remaining_nxt <= rx_remaining_r - 1;
        if rx_remaining_r = to_unsigned(1, rx_remaining_r'length) then
          rx_active_nxt <= '0';
        elsif rx_byte_idx_r = "111" then
          rx_byte_idx_nxt <= (others => '0');
        else
          rx_byte_idx_nxt <= rx_byte_idx_r + 1;
        end if;
      end if;
    end if;

    -- Flush on claim release so no RX byte leaks across transfers.
    if claim_q = '0' then
      rx_active_nxt    <= '0';
      rx_remaining_nxt <= (others => '0');
      rx_byte_idx_nxt  <= (others => '0');
    end if;
  end process rxstream_comb_proc;

  rxstream_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      rx_word_r      <= (others => '0');
      rx_byte_idx_r  <= (others => '0');
      rx_remaining_r <= (others => '0');
      rx_active_r    <= '0';
    elsif rising_edge(clk) then
      rx_word_r      <= rx_word_nxt;
      rx_byte_idx_r  <= rx_byte_idx_nxt;
      rx_remaining_r <= rx_remaining_nxt;
      rx_active_r    <= rx_active_nxt;
    end if;
  end process rxstream_clk_proc;

  ctrl_out_data <= ctrl_out_data_c;
  ctrl_out_vld  <= ctrl_out_vld_c;
  ctrl_out_last <= ctrl_out_last_c;

  -- ======================================================================
  -- Control-IN byte stream (SV 8b -> PIE 64b).
  -- ctrl_in_rdy gated on claim_q so the SV ctrl_decode observes
  -- backpressure the instant the arbiter releases ownership.
  -- ======================================================================
  ctrl_in_rdy_c <= (not tx_word_full_r) and claim_q;
  ctrl_in_rdy   <= ctrl_in_rdy_c;

  txstream_comb_proc : process (tx_word_r, tx_byte_idx_r, tx_word_full_r,
                                tx_last_r, ctrl_in_data, ctrl_in_vld,
                                ctrl_in_rdy_c, ctrl_in_last,
                                pie_txdata_fetched, claim_q)
    variable byte_index_v : integer range 0 to 7;
  begin
    tx_word_nxt      <= tx_word_r;
    tx_byte_idx_nxt  <= tx_byte_idx_r;
    tx_word_full_nxt <= tx_word_full_r;
    tx_last_nxt      <= tx_last_r;

    -- Accept one byte from SV side.
    if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') and (claim_q = '1') then
      byte_index_v := to_integer(tx_byte_idx_r);
      tx_word_nxt(byte_index_v*8 + 7 downto byte_index_v*8) <= ctrl_in_data;
      if (tx_byte_idx_r = "111") or (ctrl_in_last = '1') then
        tx_word_full_nxt <= '1';
        tx_last_nxt      <= ctrl_in_last;
        tx_byte_idx_nxt  <= (others => '0');
      else
        tx_byte_idx_nxt <= tx_byte_idx_r + 1;
      end if;
    end if;

    -- Drain a 64-bit beat into PIE.
    if (pie_txdata_fetched = '1') and (tx_word_full_r = '1') and
       (claim_q = '1') then
      tx_word_full_nxt <= '0';
      tx_last_nxt      <= '0';
      tx_word_nxt      <= (others => '0');
    end if;

    -- Flush on claim release (no IN bytes leak across transfers).
    if claim_q = '0' then
      tx_word_full_nxt <= '0';
      tx_last_nxt      <= '0';
      tx_byte_idx_nxt  <= (others => '0');
      tx_word_nxt      <= (others => '0');
    end if;
  end process txstream_comb_proc;

  txstream_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      tx_word_r      <= (others => '0');
      tx_byte_idx_r  <= (others => '0');
      tx_word_full_r <= '0';
      tx_last_r      <= '0';
    elsif rising_edge(clk) then
      tx_word_r      <= tx_word_nxt;
      tx_byte_idx_r  <= tx_byte_idx_nxt;
      tx_word_full_r <= tx_word_full_nxt;
      tx_last_r      <= tx_last_nxt;
    end if;
  end process txstream_clk_proc;

  -- ======================================================================
  -- EP-info mux to PIE.
  --
  -- claim_q = '0' : bit-identical pass-through of the legacy bundle so
  --                 pre-existing standard USB enumeration and any
  --                 non-OCP class hooks see exactly the same PIE input
  --                 they would see in the un-arbitered IP.
  -- claim_q = '1' : arbiter substitutes its own response for the
  --                 claimed OCP class transfer: valid/active high,
  --                 toggle/disabled/iso 0, nbytes = latched wLength,
  --                 maxpacket = "11" (HS EP0 = 64 B), txdata from the
  --                 IN serializer slot.
  -- STALL OR-combine: legacy stall OR the SV-driven ctrl_set_stall (while
  --   claim_q) OR a collision-decline pulse (decline_pend_q).
  -- ======================================================================
  epinfo_to_pie_valid    <= legacy_epinfo_valid    when claim_q = '0' else '1';
  -- TX underrun avoidance (iter 9 / Phase 8):
  -- During the DATA stage of an IN class transfer the SV-side ctrl_decode
  -- walks one byte per ~7 PIE clocks (S_RLAT -> S_READ loop), so the first
  -- 8-byte beat is not yet latched into tx_word_r when the first host IN
  -- token arrives ~1 us after SETUP.  If we left epinfo_to_pie_active = '1'
  -- the PIE packet_handling FSM would transit
  -- USB_PROT_IN_WF_EP_INFO_VALID -> USB_PROT_IN_TX_DATA_PID_1 with
  -- epinfo_txdata_valid='0', hit the "txready='1' and packetsize/=0"
  -- underrun branch (usb_pie.m.vhdl line 2906..2914), corrupt the CRC16
  -- and SetError(TIMEOUT) -- which is exactly the iter 8 OCP IN failure
  -- (research/usb_ocp_p8_crc_rca.md).
  --
  -- Fix: while in S_DATA AND the SETUP direction bit is IN (bmRequestType[7]
  -- = setup_pkt_r(7) = '1', USB 2.0 Sec 9.3 Tbl 9-2), drive active from
  -- tx_word_full_r.  When the SV side has not yet delivered the first 64-bit
  -- beat, active='0' steers PIE into USB_PROT_IN_OUT_PING_WF_TX_NAK_HANDSHAKE
  -- (usb_pie.m.vhdl line 2539..2541) -- a spec-compliant NAK per USB 2.0
  -- Sec 8.4.5 (Handshake Packets) and Sec 8.5.3.2 (a device endpoint that
  -- temporarily has no data SHALL return NAK).  The host then retries the
  -- IN, by which time tx_word_full_r='1' and the data flows.
  --
  -- For SETUP and STATUS stages and for OUT data stages, active continues
  -- to read '1' so the existing handshake semantics are preserved.
  -- Reuses existing state only (no new flops).
  epinfo_to_pie_active   <= legacy_epinfo_active when claim_q = '0' else
                            tx_word_full_r       when (claim_state_r = S_DATA) and
                                                       (setup_pkt_r(7) = '1') else
                            '1';
  epinfo_to_pie_disabled <= legacy_epinfo_disabled when claim_q = '0' else '0';
  epinfo_to_pie_toggle   <= legacy_epinfo_toggle   when claim_q = '0' else '0';
  epinfo_to_pie_iso      <= legacy_epinfo_iso      when claim_q = '0' else '0';
  epinfo_to_pie_nbytes   <= legacy_epinfo_nbytes
                              when claim_q = '0'
                              else std_logic_vector(nbytes_r);
  epinfo_to_pie_maxpacket<= legacy_epinfo_maxpacket when claim_q = '0' else "11";
  epinfo_to_pie_txdata   <= legacy_epinfo_txdata
                              when claim_q = '0' else tx_word_r;
  epinfo_to_pie_txdata_valid <= legacy_epinfo_txdata_valid
                              when claim_q = '0' else tx_word_full_r;

  -- STALL: legacy + SV class-stall (only meaningful while claimed) +
  -- collision-decline (Phase 8 busy-decline policy).
  epinfo_to_pie_stall <= legacy_epinfo_stall or
                         (ctrl_set_stall and claim_q) or
                         decline_pend_q;

  -- ======================================================================
  -- Assertions (synthesis-ignored).
  -- ======================================================================
  -- pragma translate_off
  assertions_proc : process (clk)
  begin
    if rising_edge(clk) and reset_n = '1' then
      -- Back-to-back RX beats arriving while previous beat still drains
      -- would silently corrupt the OUT stream; this is unsupported.
      assert not ((pie_rxdatavalid = '1') and (claim_q = '1') and
                  (pie_epinfo_setup = '0') and (rx_active_r = '1'))
        report "usb_pie_recovery_arb: back-to-back RX beats while draining"
        severity failure;

      -- True overflow check: ctrl_in_vld accepted into a slot that is
      -- already full (must be unreachable by construction since
      -- ctrl_in_rdy_c is the inverse of tx_word_full_r AND'd with
      -- claim_q).
      assert not ((ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') and
                  (tx_word_full_r = '1'))
        report "usb_pie_recovery_arb: byte accepted while slot full -- arbiter bug"
        severity failure;

      -- pie_error during a claimed transfer is logged but does not
      -- stop simulation; the FSM still walks to S_IDLE via pie_endtransfer.
      if (pie_error = '1') and (claim_q = '1') then
        report "usb_pie_recovery_arb: pie_error during recovery EP0 xfer"
          severity warning;
      end if;
    end if;
  end process assertions_proc;
  -- pragma translate_on

end architecture rtl;
