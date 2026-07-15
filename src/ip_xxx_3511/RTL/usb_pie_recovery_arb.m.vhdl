--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_pie_recovery_arb.m.vhdl
--
--  Architecture: rtl
--
--  Microarchitecture overview
--  --------------------------
--  Control plane:
--    Explicit four-state FSM (claim_state_r) walks one OCP recovery class
--    control transfer through SETUP -> DATA (optional) -> STATUS, matching
--    USB 2.0 Sec 8.5.3 control-transfer phasing.  The FSM:
--      * Decodes the OCP class match combinationally off the captured SETUP
--        beat (setup_capture_c) before the SETUP-received pulse propagates to
--        the legacy SIE.  This lets the arbiter decide ownership in the same
--        cycle that the SETUP data is visible.
--      * Asserts claim_q the same cycle the SETUP matches, so one owner is
--        established before any downstream response path is activated.
--      * Holds claim_q for the entire SETUP+DATA+STATUS sequence, counted
--        from pie_endtransfer pulses.  Path selection depends on the SETUP
--        wLength: zero -> SETUP then STATUS (no DATA); non-zero -> SETUP then
--        DATA then STATUS.
--      * On collision (a new class-match SETUP arrives while claim_q is still
--        high) the arbiter forces a STALL handshake back to PIE and drops
--        claim_q (busy-decline policy).  USB 2.0 Sec 8.5.3 mandates abandoning
--        the in-flight transfer on a fresh SETUP; the STALL reports that the
--        new request was declined instead of buffering two transfers at once.
--
--  Data plane:
--    * SETUP capture: latch pie_rxdata[63:0] when (pie_epinfo_setup AND
--      pie_rxdatavalid).  USB 2.0 Sec 8.5.3: SETUP payload is always 8 B and
--      PIE delivers it in a single 64-bit beat.
--    * RX store-and-forward buffer: the OUT data phase captures every
--      pie_rxdatavalid 64-bit beat into a full-EP0-MaxPacket (64 B) buffer
--      (rx_buf_r), then drains 32-bit words into ctrl_out_* at ctrl_out_rdy
--      pace.  The legacy PIE has no RX backpressure input (it delivers post-ACK
--      from its own RX FIFO, one pulse per 64-bit word), so a multi-beat OUT
--      transfer such as INDIRECT_FIFO_DATA (64 B = 8 beats) can deliver beat
--      N+1 before a single-slot serializer could drain beat N.  The buffer
--      absorbs the whole packet so no beat is dropped.  It is enabled only
--      while claim_q='1' and the beat is not a SETUP.
 --    * TX cut-through queue: ctrl_in_* 32b words accumulate into exactly two
 --      resident 64-bit beats (current + next) plus one 32-bit half-word
 --      assembler.  The PIE data phase is held inactive until the queue meets
 --      the launch rule implied by usb_pie sampling: <=8 B responses wait for
 --      current+producer-end, >8 B responses wait for current+next.  A visible
 --      fetch shifts next -> current only for non-final beats; the final beat
 --      remains stable through pie_endtransfer because pie_txdata_fetched does
 --      not pulse for the last beat.
 --    * wLength is latched into nbytes_r for OUT transfers. IN transfers drive
 --      epinfo_nbytes from exact response metadata supplied by the SV decoder,
 --      clipped to wLength, so short responses terminate correctly and the
 --      exact-64-B case still emits the terminating ZLP.
--    * The legacy bundle pass-through is bit-identical to the un-arbitered IP
--      whenever claim_q='0', so standard USB enumeration (GET_DESCRIPTOR /
--      SET_ADDRESS / SET_CONFIGURATION / GET_STATUS / class hooks for non-OCP
--      interfaces / ...) is unaffected.
--
--  Reuse / area note
--  -----------------
--  Counters:
--    * rx_wr_beat_r   : 4-bit (0..8)         -- OUT buffer beat write index
--    * rx_rd_widx_r   : 5-bit (0..16)        -- OUT buffer word read index
--    * rx_total_r     : 12-bit (matches pie_rx_nbytes width) staged OUT bytes
  --    * tx_curr_valid_r/tx_next_valid_r : 1 bit each -- resident 64b beats
  --    * tx_half_word_valid_r            : 1 bit      -- 32b assembler occupancy
  --    * tx_bytes_sent_r                 : 7-bit      -- bytes retired by visible fetches
  --    * nbytes_r       : 15-bit (matches epinfo_nbytes width)
  --    * claim_state_r  : 2-bit (four-state FSM enum)
  --  The OUT path accumulates whole 64-bit beats into a bounded elastic queue
  --  (rx_buf_r) and drains 32-bit words to ctrl_decode.
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture rtl of usb_pie_recovery_arb is

  -- ----------------------------------------------------------------------
  -- Constants / generics-as-slv.
  -- ----------------------------------------------------------------------
  constant BYTES_PER_BEAT : integer := USB_DATAWIDTH / 8;  -- 8 for 64b PIE
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
  -- overlapping transfers to the SV decoder.  Set decline_pend_q to force
  -- a STALL handshake for the new SETUP and drop claim back to S_IDLE.
  -- ----------------------------------------------------------------------
  type t_claim_state is (S_IDLE, S_SETUP, S_DATA, S_STATUS);
  signal claim_state_r   : t_claim_state;
  signal claim_state_nxt : t_claim_state;

  signal claim_q       : std_logic;  -- derived: '1' when not in S_IDLE

  -- Rising-edge detect of pie_endtransfer (which is held as a multi-cycle
  -- LEVEL by the PIE).  See claim_fsm_comb_proc comment for rationale.
  signal pie_endtransfer_q       : std_logic;
  signal pie_endtransfer_pulse_c : std_logic;

  -- Rising-edge detect of pie_error (also held as a multi-cycle LEVEL by the
  -- legacy PIE -- usb_pie.m.vhdl only clears it when the next host token
  -- arrives). Used solely to log the assertions_proc warning once per event
  -- instead of once per clock cycle the level is held (D3 root-cause: a
  -- single benign NAK-backpressure event, e.g. the arbiter driving
  -- epinfo_to_pie_active='0' while an IN response is still staging, was
  -- otherwise reported as dozens of duplicate warnings for the level's
  -- entire multi-cycle duration).
  signal pie_error_q       : std_logic;
  signal pie_error_pulse_c : std_logic;

  -- SETUP class-match decoded combinationally on the cycle PIE delivers
  -- the SETUP beat.  This keeps the routing decision stable before the
  -- SETUP-received notification fans out to the downstream response paths.
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

  -- Set when the STATUS-stage pie_endtransfer arrives while the OUT RX buffer
  -- is still draining to ctrl_decode.  Holds the claim FSM in S_STATUS (does
  -- not release ownership) until the drain finishes, so no buffered OUT word
  -- is lost across the transfer boundary.  Always 0 for IN transfers (the RX
  -- drain never activates).  Cleared on reset and on leaving S_STATUS.
  signal status_end_pend_r : std_logic;


  -- ----------------------------------------------------------------------
  -- SETUP capture (single 64-bit latch).  pie_epinfo_setup is high for a
  -- multi-cycle window around the SETUP beat; the pie_rxdatavalid pulse
  -- frames the cycle on which pie_rxdata holds the 8 SETUP bytes.
  -- ----------------------------------------------------------------------
  signal setup_capture_c : std_logic;
  signal setup_pkt_r     : std_logic_vector(63 downto 0);
  signal setup_pkt_vld_r : std_logic;

  -- ----------------------------------------------------------------------
  -- Per-transfer wLength budget driven into PIE's epinfo_nbytes so the
  -- TX serializer in usb_pie sees the requested byte count for the claimed
  -- transfer.  Truncated to 15 bits to match the PIE port width; OCP Recovery
  -- v1.1 register payloads are <= 256 bytes so the truncation cannot affect
  -- any spec-legal recovery transfer.
  -- ----------------------------------------------------------------------
  signal nbytes_r : unsigned(14 downto 0);
  signal tx_response_bytes_r : unsigned(6 downto 0);
  signal tx_response_known_r : std_logic;

  -- ----------------------------------------------------------------------
  -- Control-OUT elastic cut-through queue.
  --
  -- PIE delivers post-ACK 64-bit beats without a backpressure input. The
  -- queue holds three beats: one tail beat is withheld until pie_endtransfer
  -- makes pie_rx_nbytes authoritative, while older beats stream immediately
  -- as two 32-bit ctrl_out words. A successor beat proves the previous beat
  -- cannot be final, so it may be drained with a full byte mask before packet
  -- end. The final beat uses the authoritative total for its partial mask.
  --
  -- The PIE can emit a CRC-flush beat after payload delivery. Capture is
  -- bounded by the SETUP wLength-derived expected beat count, and the final
  -- ctrl_out_last terminates on rx_total_r, so a flush tail is never emitted.
  -- ctrl_xfer_done remains sourced from rx_drain_done_r after the final valid
  -- word is accepted.
  -- ----------------------------------------------------------------------
  constant RX_ELASTIC_BEATS : integer := 3;

  type t_rx_buf is array (0 to RX_ELASTIC_BEATS-1)
                     of std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_buf_r            : t_rx_buf;
  signal rx_wr_beat_r        : unsigned(1 downto 0);
  signal rx_rd_beat_r        : unsigned(1 downto 0);
  signal rx_count_r          : unsigned(1 downto 0);
  signal rx_captured_beats_r : unsigned(3 downto 0);
  signal rx_rd_word_r        : std_logic;
  signal rx_word_index_r     : unsigned(4 downto 0);
  signal rx_total_r          : unsigned(11 downto 0);
  signal rx_end_seen_r       : std_logic;
  signal rx_drain_done_r     : std_logic;

  signal rx_expected_beats_c : unsigned(3 downto 0);
  signal rx_drain_enable_c   : std_logic;
  signal rx_last_word_c      : std_logic;
  signal ctrl_out_data_c     : std_logic_vector(31 downto 0);
  signal ctrl_out_be_c       : std_logic_vector(3 downto 0);
  signal ctrl_out_vld_c      : std_logic;
  signal ctrl_out_last_c     : std_logic;

  -- ----------------------------------------------------------------------
  -- Control-IN elastic queue.
  --
  -- The S1 hardware read path produces a 64-bit response beat faster than the
  -- PIE fetch cadence. Two resident beats plus a one-word assembler are enough
  -- to absorb fetch handshakes while allowing the data phase to activate as
  -- soon as the first complete beat is ready.
  -- The arbiter:
  --   * holds exactly two 64-bit beats plus one 32-bit half-word assembler.
  --     The decoder supplies exact implementation byte-count metadata during
  --     S_SETUP, so the arbiter can activate as soon as the queue guarantees
  --     the PIE's sampling contract:
  --       - responses <= 8 B wait for the final producer beat
  --       - responses > 8 B wait for current+next beats to be valid
  --   * shifts next -> current only on a visible PIE fetch for a non-final
  --     beat. The final current beat remains valid and data-stable until
  --     pie_endtransfer because usb_pie samples epinfo_txdata every beat while
  --     pie_txdata_fetched pulses only for non-final beats.
  --   * drives epinfo_to_pie_nbytes from the captured exact metadata, never
  --     from wLength or an accumulated staging count, so short responses and
  --     the exact-64-B terminating-ZLP case follow USB 2.0 Sec 5.5.3 /
  --     Sec 8.5.3 precisely.
  --   * flushes queue state on claim release or a fresh SETUP, preventing data
  --     leakage across transfers.
  --
  -- Scope: a single MaxPacket (<= 64 bytes).  All current OCP recovery IN
  -- responses fit one EP0 HS packet (DEVICE_STATUS = 64 bytes is the max).
  -- Multi-packet IN (wLength > 64) is OUT OF SCOPE for this milestone.
  -- ----------------------------------------------------------------------
  constant TX_MAXBYTES : integer := 64;
  signal tx_curr_data_r       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_curr_valid_r      : std_logic;
  signal tx_next_data_r       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_next_valid_r      : std_logic;
  signal tx_half_word_r       : std_logic_vector(31 downto 0);
  signal tx_half_word_valid_r : std_logic;
  signal tx_producer_done_r   : std_logic;
  signal tx_bytes_sent_r      : unsigned(6 downto 0);
  signal tx_packet_started_r  : std_logic;
  signal xfer_dir_in_r        : std_logic;             -- latched SETUP IN dir

  signal ctrl_in_rdy_c        : std_logic;
  signal tx_in_data_c         : std_logic;             -- claim & S_DATA & dir=IN & data pkt
  signal tx_launch_ready_c    : std_logic;
  signal tx_beat_valid_c      : std_logic;
  signal tx_shift_c           : std_logic;
  signal tx_slot_free_c       : std_logic;
  signal tx_remaining_bytes_c : unsigned(6 downto 0);

  -- Data-stage toggle sequencing for IN control reads (USB 2.0 Sec 5.5.3 /
  -- Sec 8.6).  in_data_toggle_r is the running per-packet DATA toggle: it
  -- starts at DATA1 for the first data packet and alternates on each DATA-stage
  -- end.  An IN read whose response is an exact MaxPacket multiple (here a
  -- single 64-byte EP0 packet) requires a terminating zero-length packet to
  -- close the data stage; zlp_phase_r marks the one cycle span over which that
  -- terminator is emitted while the FSM stays in S_DATA.
  signal in_data_toggle_r  : std_logic;             -- running DATA-stage toggle (DATA1 first)
  signal zlp_phase_r       : std_logic;             -- emitting the terminating ZLP in S_DATA
  signal zlp_owed_c        : std_logic;             -- exact-MaxPacket IN read owes a ZLP

  function mask_word32(data : std_logic_vector(31 downto 0);
                       be   : std_logic_vector(3 downto 0))
    return std_logic_vector is
    variable masked_v : std_logic_vector(31 downto 0);
  begin
    masked_v := (others => '0');
    for idx in 0 to 3 loop
      if be(idx) = '1' then
        masked_v(idx*8+7 downto idx*8) := data(idx*8+7 downto idx*8);
      end if;
    end loop;
    return masked_v;
  end function;

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
      tx_response_bytes_r  <= (others => '0');
      tx_response_known_r  <= '0';
      last_setup_was_ocp_q <= '0';
      xfer_dir_in_r        <= '0';
    elsif rising_edge(clk) then
      -- Default: drop pulse.
      setup_pkt_vld_r <= '0';
      if setup_capture_c = '1' then
        setup_pkt_r <= pie_rxdata;
        -- wLength little-endian at bytes 6..7 of the SETUP payload
        -- (USB 2.0 Sec 9.3 Tbl 9-2).  Bit 63 is dropped to fit the
        -- 15-bit PIE nbytes port (see nbytes_r decl comment).
        nbytes_r <= unsigned(pie_rxdata(62 downto 48));
        tx_response_bytes_r <= (others => '0');
        tx_response_known_r <= '0';
        -- Latch the transfer direction so the TX active gate knows
        -- whether the upcoming DATA stage is an IN (device->host) response
        -- that must be fully staged before the PIE is activated.
        xfer_dir_in_r <= setup_dir_in_c;
        -- Pre-filtered SETUP-vld pulse delivered to SV ctrl_decode only
        -- when this SETUP matches the OCP class; the SV side therefore
        -- never sees a standard or unrelated-class SETUP.
        setup_pkt_vld_r      <= setup_is_ocp_match_c;
        last_setup_was_ocp_q <= setup_is_ocp_match_c;
      elsif claim_state_r = S_SETUP then
        tx_response_bytes_r <= unsigned(ctrl_in_resp_bytes);
        tx_response_known_r <= ctrl_in_resp_known;
      elsif claim_q = '0' then
        tx_response_bytes_r <= (others => '0');
        tx_response_known_r <= '0';
      end if;
    end if;
  end process setup_clk_proc;

  setup_pkt     <= setup_pkt_r;
  setup_pkt_vld <= setup_pkt_vld_r;

  -- ======================================================================
  -- Class-match decode (combinational; cycle setup_capture_c='1').
  -- ======================================================================
  -- C1 emergency-fallback chicken bit: AND NOT ocp_path_disable_i suppresses
  -- the class match unconditionally so the arbiter never claims (falls
  -- through to legacy SIE pass-through, bit-identical to the un-arbitered
  -- IP) regardless of the SETUP's OCP-class encoding.
  setup_is_ocp_match_c <= '1' when (setup_capture_c           = '1')
                                and (pie_rxdata( 6 downto  5) = "01")
                                and (pie_rxdata( 4 downto  0) = "00001")
                                and (pie_rxdata(15 downto  8) = OCP_RECOVERY_TRANSFER)
                                and (pie_rxdata(39 downto 32) = REC_IFACE_SLV)
                                and (pie_rxdata(47 downto 40) = x"00")
                                and (ocp_path_disable_i       = '0')
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
  --     ctrl_xfer_done.  The FSM consumes it internally to advance
  --     S_SETUP -> S_DATA or S_STATUS.
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
                                 nbytes_r, rx_count_r, status_end_pend_r,
                                 zlp_phase_r, zlp_owed_c)
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
          -- An exact-MaxPacket IN read (zlp_owed_c) needs a terminating
          -- zero-length data packet (USB 2.0 Sec 5.5.3 / 8.5.3.2).  Stay in
          -- S_DATA one more packet to emit that ZLP (zlp_phase_r) before
          -- advancing to the real STATUS handshake; all other cases advance.
          if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
            claim_state_nxt <= S_DATA;
          else
            claim_state_nxt <= S_STATUS;
          end if;
        end if;

      when S_STATUS =>
        if setup_capture_c = '1' then
          if setup_is_ocp_match_c = '1' then
            claim_state_nxt <= S_SETUP;
          else
            claim_state_nxt <= S_IDLE;
          end if;
        elsif ((pie_endtransfer_pulse_c = '1') or (status_end_pend_r = '1'))
              and (rx_count_r = to_unsigned(0, rx_count_r'length)) then
          -- Hold ownership until the OUT elastic queue has fully drained to
          -- ctrl_decode. For IN transfers the queue remains empty, so this
          -- reduces to the plain pie_endtransfer release. status_end_pend_r
          -- captures a STATUS-end pulse that arrives before the tail drains.
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
  -- The legacy IP-3511 SetError() process pairs set_pie_endtransfer
  -- with set_pie_error, so pie_endtransfer also
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

  -- pie_error edge detector (D3): pie_error is a multi-cycle LEVEL (cleared
  -- only when the legacy PIE's PID-decode FSM sees the next host token), so
  -- rising_edge-only qualification is required to log the assertions_proc
  -- warning once per event rather than once per clock while the level holds.
  pie_error_pulse_c <= pie_error and not pie_error_q;

  pie_error_edge_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      pie_error_q <= '0';
    elsif rising_edge(clk) then
      pie_error_q <= pie_error;
    end if;
  end process pie_error_edge_proc;

  claim_fsm_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      claim_state_r     <= S_IDLE;
      decline_pend_q    <= '0';
      status_end_pend_r <= '0';
      in_data_toggle_r  <= '1';
      zlp_phase_r       <= '0';
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
      -- status_end_pend_r: latch a STATUS-stage end that arrives while the
      -- OUT elastic queue still contains valid beats, so the
      -- S_STATUS->S_IDLE release is deferred until the final word drains.
      if claim_state_r = S_STATUS then
        if (pie_endtransfer_pulse_c = '1') and
           (rx_count_r /= to_unsigned(0, rx_count_r'length)) then
          status_end_pend_r <= '1';
        end if;
      else
        status_end_pend_r <= '0';
      end if;
      -- Data-stage toggle + terminating-ZLP phase (USB 2.0 Sec 5.5.3 / 8.6).
      -- Reset to DATA1 / no-ZLP at a transfer boundary or fresh SETUP.  On a
      -- DATA-stage end, if a terminating ZLP is owed and not yet sent, flip the
      -- toggle (DATA1 -> DATA0) and enter the ZLP phase; otherwise clear it.
      if (claim_q = '0') or (setup_capture_c = '1') then
        in_data_toggle_r <= '1';
        zlp_phase_r      <= '0';
      elsif (claim_state_r = S_DATA) and (pie_endtransfer_pulse_c = '1') then
        if (zlp_phase_r = '0') and (zlp_owed_c = '1') then
          zlp_phase_r      <= '1';
          in_data_toggle_r <= not in_data_toggle_r;
        else
          zlp_phase_r <= '0';
        end if;
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
  -- This is the sole mechanism that prevents the MCU EPCS from being
  -- notified of recovery-class SETUPs.  No downstream flop is required.
  -- ======================================================================
  legacy_setup_received_gated <= pie_epinfo_setup_received and
                                 (not last_setup_was_ocp_q) and
                                 (not setup_is_ocp_match_c);

  -- ======================================================================
  -- xfer-done re-emission to SV.
  --   * IN transfers (xfer_dir_in_r='1'): pulse on the DATA/STATUS-stage
  --     pie_endtransfer rising edge, BUT only after the launch contract is
  --     satisfied (tx_launch_ready_c='1'). The host's first IN token can
  --     arrive while the elastic queue is still filling, and the
  --     PIE legitimately NAKs it (NAK raises pie_endtransfer).  Without the
  --     tx_launch_ready_c qualifier that NAK edge would fire ctrl_xfer_done
  --     and trip ctrl_decode's early-termination escape, abandoning staging
  --     to S_IDLE so the response never completes (the PIE then NAKs every
  --     retry -> host reads zeros). Gating on tx_launch_ready_c lets staging
  --     reach the required two-beat or final-beat condition before the decoder
  --     observes transfer completion.
  --   * OUT transfers (xfer_dir_in_r='0'): the RX queue drains to ctrl_decode
  --     AFTER the DATA-stage pie_endtransfer (the PIE delivers all beats then
  --     ends the stage).  Sourcing ctrl_xfer_done from the pie_endtransfer
  --     edge would abort ctrl_decode mid-drain.  Instead pulse from
  --     rx_drain_done_r, emitted when the last buffered word is accepted.
  -- ======================================================================
  ctrl_xfer_done <= rx_drain_done_r when (xfer_dir_in_r = '0')
                    else (pie_endtransfer and not pie_endtransfer_q and
                          tx_launch_ready_c)
                           when (claim_state_r = S_DATA) or
                                (claim_state_r = S_STATUS)
                     else '0';

  -- ======================================================================
  -- Control-OUT elastic queue (PIE 64b beats -> SV 32b words).
  -- ======================================================================
  rx_expected_beats_c <= resize(shift_right(nbytes_r +
                                            to_unsigned(BYTES_PER_BEAT-1,
                                                        nbytes_r'length), 3), 4);
  rx_drain_enable_c <= '1' when (rx_count_r /= to_unsigned(0, rx_count_r'length))
                                and ((rx_count_r > to_unsigned(1, rx_count_r'length))
                                     or (rx_end_seen_r = '1'))
                       else '0';

  rxstream_comb_proc : process (rx_drain_enable_c, rx_rd_beat_r, rx_rd_word_r,
                                 rx_word_index_r, rx_total_r, rx_end_seen_r, rx_buf_r)
    variable beat_v : integer range 0 to RX_ELASTIC_BEATS-1;
    variable word_v : std_logic_vector(31 downto 0);
    variable rem_v  : unsigned(11 downto 0);
  begin
    ctrl_out_data_c <= (others => '0');
    ctrl_out_be_c   <= (others => '0');
    ctrl_out_vld_c  <= '0';
    ctrl_out_last_c <= '0';
    rx_last_word_c  <= '0';

    if rx_drain_enable_c = '1' then
      beat_v := to_integer(rx_rd_beat_r);
      if rx_rd_word_r = '0' then
        word_v := rx_buf_r(beat_v)(31 downto 0);
      else
        word_v := rx_buf_r(beat_v)(63 downto 32);
      end if;
      ctrl_out_data_c <= word_v;
      ctrl_out_vld_c  <= '1';

      if rx_end_seen_r = '0' then
        ctrl_out_be_c <= "1111";
      else
        rem_v := rx_total_r -
                 to_unsigned(to_integer(rx_word_index_r) * 4, rem_v'length);
        if rem_v >= to_unsigned(4, rem_v'length) then
          ctrl_out_be_c <= "1111";
        else
          case to_integer(rem_v(1 downto 0)) is
            when 1      => ctrl_out_be_c <= "0001";
            when 2      => ctrl_out_be_c <= "0011";
            when 3      => ctrl_out_be_c <= "0111";
            when others => ctrl_out_be_c <= "1111";
          end case;
        end if;

        if rem_v <= to_unsigned(4, rem_v'length) then
          ctrl_out_last_c <= '1';
          rx_last_word_c  <= '1';
        end if;
      end if;
    end if;
  end process rxstream_comb_proc;

  rxbuf_clk_proc : process (clk, reset_n)
    variable capture_v : boolean;
    variable pop_v     : boolean;
  begin
    if reset_n = '0' then
      for i in 0 to RX_ELASTIC_BEATS-1 loop
        rx_buf_r(i) <= (others => '0');
      end loop;
      rx_wr_beat_r        <= (others => '0');
      rx_rd_beat_r        <= (others => '0');
      rx_count_r          <= (others => '0');
      rx_captured_beats_r <= (others => '0');
      rx_rd_word_r        <= '0';
      rx_word_index_r     <= (others => '0');
      rx_total_r          <= (others => '0');
      rx_end_seen_r       <= '0';
      rx_drain_done_r     <= '0';
    elsif rising_edge(clk) then
      rx_drain_done_r <= '0';

      if (claim_q = '0') or (setup_capture_c = '1') then
        for i in 0 to RX_ELASTIC_BEATS-1 loop
          rx_buf_r(i) <= (others => '0');
        end loop;
        rx_wr_beat_r        <= (others => '0');
        rx_rd_beat_r        <= (others => '0');
        rx_count_r          <= (others => '0');
        rx_captured_beats_r <= (others => '0');
        rx_rd_word_r        <= '0';
        rx_word_index_r     <= (others => '0');
        rx_total_r          <= (others => '0');
        rx_end_seen_r       <= '0';
      else
        -- A normal 64-bit beat retires after its high word. A partial final
        -- beat may end on its low word, so rx_last_word_c also retires it and
        -- emits ctrl_xfer_done without waiting for a non-existent high word.
        pop_v := (rx_drain_enable_c = '1') and
                 (ctrl_out_rdy = '1') and
                 ((rx_rd_word_r = '1') or (ctrl_out_last_c = '1'));
        capture_v := (pie_rxdatavalid = '1') and
                     (pie_epinfo_setup = '0') and
                     (rx_captured_beats_r < rx_expected_beats_c) and
                     ((rx_count_r < to_unsigned(RX_ELASTIC_BEATS,
                                                 rx_count_r'length)) or pop_v);

        if capture_v then
          rx_buf_r(to_integer(rx_wr_beat_r)) <= pie_rxdata;
          if rx_wr_beat_r = to_unsigned(RX_ELASTIC_BEATS-1,
                                        rx_wr_beat_r'length) then
            rx_wr_beat_r <= (others => '0');
          else
            rx_wr_beat_r <= rx_wr_beat_r + 1;
          end if;
          rx_captured_beats_r <= rx_captured_beats_r + 1;
        end if;

        if pop_v then
          if ctrl_out_last_c = '1' then
            rx_drain_done_r <= '1';
          end if;
          if rx_rd_beat_r = to_unsigned(RX_ELASTIC_BEATS-1,
                                        rx_rd_beat_r'length) then
            rx_rd_beat_r <= (others => '0');
          else
            rx_rd_beat_r <= rx_rd_beat_r + 1;
          end if;
        end if;

        if capture_v and not pop_v then
          rx_count_r <= rx_count_r + 1;
        elsif pop_v and not capture_v then
          rx_count_r <= rx_count_r - 1;
        end if;

        if (rx_drain_enable_c = '1') and (ctrl_out_rdy = '1') then
          if rx_rd_word_r = '0' then
            rx_rd_word_r    <= '1';
            rx_word_index_r <= rx_word_index_r + 1;
          else
            rx_rd_word_r    <= '0';
            rx_word_index_r <= rx_word_index_r + 1;
          end if;
        end if;

        if (pie_endtransfer_pulse_c = '1') and (claim_state_r = S_DATA) and
           (xfer_dir_in_r = '0') then
          rx_total_r    <= unsigned(pie_rx_nbytes);
          rx_end_seen_r <= '1';
          if unsigned(pie_rx_nbytes) = 0 then
            rx_drain_done_r <= '1';
          end if;
        end if;
      end if;
    end if;
  end process rxbuf_clk_proc;

  ctrl_out_data <= ctrl_out_data_c;
  ctrl_out_be   <= ctrl_out_be_c;
  ctrl_out_vld  <= ctrl_out_vld_c;
  ctrl_out_last <= ctrl_out_last_c;

  -- ======================================================================
  -- Control-IN elastic queue (SV 32b words -> PIE 64b beats).
  -- ======================================================================
  tx_in_data_c <= '1' when (claim_q = '1') and
                           (claim_state_r = S_DATA) and
                           (xfer_dir_in_r = '1') and
                           (zlp_phase_r = '0')
                   else '0';
  tx_remaining_bytes_c <= tx_response_bytes_r - tx_bytes_sent_r
                          when tx_response_bytes_r >= tx_bytes_sent_r
                          else (others => '0');
  tx_shift_c <= '1' when (tx_in_data_c = '1') and
                          (tx_launch_ready_c = '1') and
                          (pie_txdata_fetched = '1') and
                         (tx_remaining_bytes_c > to_unsigned(BYTES_PER_BEAT,
                                                             tx_remaining_bytes_c'length)) and
                         (tx_next_valid_r = '1')
                else '0';
  tx_slot_free_c <= '1' when (tx_shift_c = '1') or
                             (tx_curr_valid_r = '0') or
                             (tx_next_valid_r = '0')
                    else '0';
  ctrl_in_rdy_c <= '1' when (claim_q = '1') and (tx_slot_free_c = '1')
                    else '0';
  ctrl_in_rdy   <= ctrl_in_rdy_c;

  zlp_owed_c <= '1' when (xfer_dir_in_r = '1') and
                         (tx_response_known_r = '1') and
                         (tx_response_bytes_r = to_unsigned(TX_MAXBYTES,
                                                            tx_response_bytes_r'length))
                  else '0';
  tx_launch_ready_c <= '1' when (tx_response_bytes_r = to_unsigned(0,
                                                                    tx_response_bytes_r'length)) and
                                  (tx_producer_done_r = '1')
                        else '1' when (tx_response_bytes_r <= to_unsigned(BYTES_PER_BEAT,
                                                                           tx_response_bytes_r'length)) and
                                       (tx_curr_valid_r = '1') and
                                       (tx_producer_done_r = '1')
                        else '1' when (tx_curr_valid_r = '1') and
                                       (tx_packet_started_r = '1')
                        else '1' when (tx_curr_valid_r = '1') and
                                        (tx_next_valid_r = '1')
                       else '0';
  tx_beat_valid_c <= '1' when (tx_launch_ready_c = '1') and
                              (tx_curr_valid_r = '1') and
                              (tx_response_bytes_r /= to_unsigned(0,
                                                                  tx_response_bytes_r'length))
                      else '0';

  txbuf_clk_proc : process (clk, reset_n)
    variable curr_data_v  : std_logic_vector(USB_DATAWIDTH-1 downto 0);
    variable curr_valid_v : std_logic;
    variable next_data_v  : std_logic_vector(USB_DATAWIDTH-1 downto 0);
    variable next_valid_v : std_logic;
    variable half_word_v  : std_logic_vector(31 downto 0);
    variable half_valid_v : std_logic;
    variable producer_done_v : std_logic;
    variable bytes_sent_v : unsigned(6 downto 0);
    variable beat_v       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  begin
    if reset_n = '0' then
      tx_curr_data_r       <= (others => '0');
      tx_curr_valid_r      <= '0';
      tx_next_data_r       <= (others => '0');
      tx_next_valid_r      <= '0';
      tx_half_word_r       <= (others => '0');
      tx_half_word_valid_r <= '0';
      tx_producer_done_r   <= '0';
      tx_bytes_sent_r      <= (others => '0');
      tx_packet_started_r  <= '0';
    elsif rising_edge(clk) then
      if (claim_q = '0') or (setup_capture_c = '1') then
        tx_curr_data_r       <= (others => '0');
        tx_curr_valid_r      <= '0';
        tx_next_data_r       <= (others => '0');
        tx_next_valid_r      <= '0';
        tx_half_word_r       <= (others => '0');
        tx_half_word_valid_r <= '0';
        tx_producer_done_r   <= '0';
        tx_bytes_sent_r      <= (others => '0');
        tx_packet_started_r  <= '0';
      else
        curr_data_v     := tx_curr_data_r;
        curr_valid_v    := tx_curr_valid_r;
        next_data_v     := tx_next_data_r;
        next_valid_v    := tx_next_valid_r;
        half_word_v     := tx_half_word_r;
        half_valid_v    := tx_half_word_valid_r;
        producer_done_v := tx_producer_done_r;
        bytes_sent_v    := tx_bytes_sent_r;

        if tx_shift_c = '1' then
          curr_data_v  := tx_next_data_r;
          curr_valid_v := '1';
          next_data_v  := (others => '0');
          next_valid_v := '0';
          bytes_sent_v := tx_bytes_sent_r +
                          to_unsigned(BYTES_PER_BEAT, tx_bytes_sent_r'length);
        end if;

        if (tx_in_data_c = '1') and (tx_launch_ready_c = '1') and
           (pie_txdata_fetched = '1') then
          tx_packet_started_r <= '1';
        end if;

        if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') then
          if ctrl_in_last = '1' then
            beat_v := (others => '0');
            if half_valid_v = '1' then
              beat_v(31 downto 0)  := half_word_v;
              beat_v(63 downto 32) := mask_word32(ctrl_in_data, ctrl_in_be);
              half_word_v  := (others => '0');
              half_valid_v := '0';
            else
              beat_v(31 downto 0) := mask_word32(ctrl_in_data, ctrl_in_be);
            end if;
            if curr_valid_v = '0' then
              curr_data_v  := beat_v;
              curr_valid_v := '1';
            elsif next_valid_v = '0' then
              next_data_v  := beat_v;
              next_valid_v := '1';
            end if;
            producer_done_v := '1';
          else
            if half_valid_v = '1' then
              beat_v := (others => '0');
              beat_v(31 downto 0)  := half_word_v;
              beat_v(63 downto 32) := mask_word32(ctrl_in_data, ctrl_in_be);
              half_word_v  := (others => '0');
              half_valid_v := '0';
              if curr_valid_v = '0' then
                curr_data_v  := beat_v;
                curr_valid_v := '1';
              elsif next_valid_v = '0' then
                next_data_v  := beat_v;
                next_valid_v := '1';
              end if;
            else
              half_word_v  := mask_word32(ctrl_in_data, ctrl_in_be);
              half_valid_v := '1';
            end if;
          end if;
        end if;

        tx_curr_data_r       <= curr_data_v;
        tx_curr_valid_r      <= curr_valid_v;
        tx_next_data_r       <= next_data_v;
        tx_next_valid_r      <= next_valid_v;
        tx_half_word_r       <= half_word_v;
        tx_half_word_valid_r <= half_valid_v;
        tx_producer_done_r   <= producer_done_v;
        tx_bytes_sent_r      <= bytes_sent_v;
      end if;
    end if;
  end process txbuf_clk_proc;

  -- ======================================================================
  -- EP-info mux to PIE.
  --
  -- claim_q = '0' : bit-identical pass-through of the legacy bundle so
  --                 pre-existing standard USB enumeration and any
  --                 non-OCP class hooks see exactly the same PIE input
  --                 they would see in the un-arbitered IP.
  -- claim_q = '1' : arbiter substitutes its own response for the
  --                 claimed OCP class transfer: valid/active high,
  --                 toggle/disabled/iso 0, nbytes = captured exact response
  --                 metadata for IN or latched wLength for OUT, maxpacket =
  --                 "00" (HS EP0 control = 64 B), txdata from the current slot.
  -- STALL OR-combine: legacy stall OR the SV-driven ctrl_set_stall (while
  --   claim_q) OR a collision-decline pulse (decline_pend_q).
  -- ======================================================================
  epinfo_to_pie_valid    <= legacy_epinfo_valid    when claim_q = '0' else '1';
  -- For a claimed IN DATA stage, NAK until the exact-byte launch rule is met:
  -- current+producer_done for <=8 B, current+next for >8 B, or producer_done
  -- for a zero-byte short packet. After activation, tx_shift_c only advances
  -- the queue on non-final fetches, so the current beat stays stable through
  -- the final pie_endtransfer.
  epinfo_to_pie_active   <= legacy_epinfo_active when claim_q = '0'
                             else '0' when (tx_in_data_c = '1') and
                                          (tx_launch_ready_c = '0')
                             else '1';
  epinfo_to_pie_disabled <= legacy_epinfo_disabled when claim_q = '0' else '0';
  -- USB 2.0 Sec 5.5.3 / 8.6 control-transfer data toggle.  The DATA stage
  -- starts at DATA1 and alternates per packet; an exact-MaxPacket IN read
  -- emits a terminating DATA0 ZLP while still in S_DATA (in_data_toggle_r
  -- carries the running value, flipped for the ZLP).  The STATUS stage is
  -- always DATA1 (USB 2.0 Sec 8.5.3).
  epinfo_to_pie_toggle   <= legacy_epinfo_toggle when claim_q = '0'
                            else in_data_toggle_r when (claim_state_r = S_DATA)
                            else '1' when (claim_state_r = S_STATUS)
                            else '0';
  epinfo_to_pie_iso      <= legacy_epinfo_iso      when claim_q = '0' else '0';
  -- Claimed byte-count budget driven to the PIE:
  --   * IN DATA stage  -> command-defined response length captured at SETUP,
  --     so a short command emits a correct short packet before its final word
  --     is assembled.
  --   * STATUS stage   -> 0, so the status packet is a zero-length DATA1 (an
  --     IN STATUS ZLP for an OUT transfer, or the OUT STATUS ACK for an IN
  --     transfer).  A non-zero STATUS nbytes makes the PIE try to transmit data
  --     it does not have and underrun.
  --   * Terminating ZLP (zlp_phase_r) -> 0, so the in-S_DATA terminator for an
  --     exact-MaxPacket IN read is emitted as a true zero-length packet.
  --   * OUT DATA stage -> wLength-derived budget (nbytes_r), the expected
  --     receive count.
  epinfo_to_pie_nbytes   <= legacy_epinfo_nbytes
                              when claim_q = '0'
                              else (others => '0')
                              when (claim_state_r = S_STATUS) or (zlp_phase_r = '1')
                              else std_logic_vector(resize(tx_response_bytes_r, 15))
                              when tx_in_data_c = '1'
                              else std_logic_vector(nbytes_r);
  -- HS EP0 is a control endpoint with MaxPacketSize 64: encoding "00"
  -- (usb_pie.m.vhdl packetsize(): "00" => v_maxpacket=64 for HS Control).
  -- "11" would select the HS iso/interrupt 1024 budget and also mis-set the
  -- epinfo_maxpacket(1) iso/interrupt classifier used by the OUT handshake.
  epinfo_to_pie_maxpacket<= legacy_epinfo_maxpacket when claim_q = '0' else "00";
   epinfo_to_pie_txdata   <= legacy_epinfo_txdata
                               when claim_q = '0'
                               else tx_curr_data_r;
  epinfo_to_pie_txdata_valid <= legacy_epinfo_txdata_valid
                              when claim_q = '0' else tx_beat_valid_c;

  -- STALL: legacy + SV class-stall (only meaningful while claimed) +
  -- collision-decline for a fresh class SETUP that arrives while claim is held.
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
      -- Single EP0 MaxPacket remains the supported OUT scope. The elastic
      -- queue bounds resident beats rather than buffering the whole packet.
      assert not ((rx_end_seen_r = '1') and
                  (rx_total_r > to_unsigned(64, rx_total_r'length)))
        report "usb_pie_recovery_arb: OUT byte count exceeds EP0 MaxPacket"
        severity failure;

      assert rx_count_r <= to_unsigned(RX_ELASTIC_BEATS, rx_count_r'length)
        report "usb_pie_recovery_arb: RX elastic queue overflow"
        severity failure;

      assert not ((ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') and
                  (tx_slot_free_c = '0'))
        report "usb_pie_recovery_arb: TX queue accepted a word without free capacity"
        severity failure;

      assert (tx_response_bytes_r <= to_unsigned(TX_MAXBYTES, tx_response_bytes_r'length))
        report "usb_pie_recovery_arb: response metadata exceeds the single-packet bound"
        severity failure;

      if (tx_in_data_c = '1') and (tx_launch_ready_c = '1') then
        if tx_response_bytes_r = to_unsigned(0, tx_response_bytes_r'length) then
          assert tx_producer_done_r = '1'
            report "usb_pie_recovery_arb: zero-byte launch occurred before producer end"
            severity failure;
        elsif tx_response_bytes_r <= to_unsigned(BYTES_PER_BEAT, tx_response_bytes_r'length) then
          assert (tx_curr_valid_r = '1') and (tx_producer_done_r = '1')
            report "usb_pie_recovery_arb: <=8B launch requires current beat and producer end"
            severity failure;
        elsif tx_packet_started_r = '1' then
          assert tx_curr_valid_r = '1'
            report "usb_pie_recovery_arb: started packet lost its current beat"
            severity failure;
        else
          assert (tx_curr_valid_r = '1') and (tx_next_valid_r = '1')
            report "usb_pie_recovery_arb: >8B launch requires current and next beats"
            severity failure;
        end if;
      end if;

      if (pie_txdata_fetched = '1') and (tx_in_data_c = '1') and
         (tx_launch_ready_c = '1') then
        assert (tx_in_data_c = '1') and
                (tx_remaining_bytes_c > to_unsigned(BYTES_PER_BEAT,
                                                    tx_remaining_bytes_c'length)) and
                (tx_next_valid_r = '1')
          report "usb_pie_recovery_arb: fetched beat lacked a non-final successor"
          severity failure;
      end if;

      if (tx_in_data_c = '1') and
         (tx_remaining_bytes_c <= to_unsigned(BYTES_PER_BEAT,
                                              tx_remaining_bytes_c'length)) and
         (pie_endtransfer_pulse_c = '0') then
        assert (tx_shift_c = '0') and tx_curr_data_r'stable and
               tx_curr_valid_r'stable
          report "usb_pie_recovery_arb: final beat changed before pie_endtransfer"
          severity failure;
      end if;

      if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '0') then
        assert ctrl_in_data'stable and ctrl_in_be'stable and
               ctrl_in_last'stable
          report "usb_pie_recovery_arb: ctrl_in source changed while backpressured"
          severity failure;
      end if;

      if (ctrl_in_vld = '1') and (ctrl_in_last = '0') then
        assert ctrl_in_be = "1111"
          report "usb_pie_recovery_arb: non-final ctrl_in word was not full-width"
          severity failure;
      end if;

      if (tx_half_word_valid_r = '1') and (tx_producer_done_r = '1') then
        assert false
          report "usb_pie_recovery_arb: producer ended with an uncommitted half word"
          severity failure;
      end if;

      -- pie_error during a claimed transfer is logged but does not
      -- stop simulation; the FSM still walks to S_IDLE via pie_endtransfer.
      -- Edge-detected (pie_error_pulse_c) so a single benign NAK-backpressure
      -- event (pie_error is a multi-cycle LEVEL, held until the next host
      -- token) is logged once, not once per clock cycle for the level's
      -- entire duration.
      if (pie_error_pulse_c = '1') and (claim_q = '1') then
        report "usb_pie_recovery_arb: pie_error during recovery EP0 xfer"
          severity warning;
      end if;
    end if;
  end process assertions_proc;
  -- pragma translate_on

end architecture rtl;
