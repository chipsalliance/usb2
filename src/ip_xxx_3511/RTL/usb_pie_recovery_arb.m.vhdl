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
--    * TX store-and-forward buffer: ctrl_in_* 32b words accumulate into a
--      full-EP0-MaxPacket (64 B) buffer.  The PIE data phase is held inactive
--      (NAKing early host IN tokens) until the whole IN response is staged,
--      then activated with the actual staged byte count.  The buffered beats
--      drain to PIE txdata with no possibility of a late beat (no underrun).
--      ctrl_in_rdy honours both buffer-full backpressure and claim_q so the SV
--      producer sees backpressure the cycle the arbiter releases ownership.
--      Buffer state is flushed whenever claim_q='0' so no response leaks across
--      transfer boundaries.
--    * wLength latched into nbytes_r and driven into PIE's epinfo_nbytes so
--      the data-stage length matches the host-requested byte count when the
--      transfer is presented to usb_pie.
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
--    * tx_wr_widx_r   : 5-bit (0..16)        -- IN buffer word write index
--    * tx_rd_beat_r   : 4-bit (0..8)         -- IN buffer beat read index
--    * tx_nbytes_r    : 7-bit (0..64)        -- staged IN byte count
--    * nbytes_r       : 15-bit (matches epinfo_nbytes width)
--    * claim_state_r  : 2-bit (four-state FSM enum)
--  The OUT path accumulates whole 64-bit beats into a full-MaxPacket
--  store-and-forward buffer (rx_buf_r), symmetric to the IN tx_buf_r buffer,
--  then drains 32-bit words to ctrl_decode.
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

  -- ----------------------------------------------------------------------
  -- Control-OUT store-and-forward buffer.
  --
  -- The legacy PIE drives pie_rxdatavalid as a 1-cycle pulse once per 64-bit
  -- received word (every 8 bytes) and has NO RX backpressure input -- it
  -- delivers from its own post-ACK RX FIFO.  A depth-1 serializer could not
  -- drain a beat (2 x 32-bit ctrl_decode words, gated by ctrl_out_rdy) before
  -- the next beat arrived, so multi-beat OUT transfers (INDIRECT_FIFO_DATA,
  -- 64 B = 8 beats) dropped beats.  The buffer absorbs the whole packet:
  --   * CAPTURE: each pie_rxdatavalid beat (claim_q, NOT SETUP) is written to
  --     rx_buf_r at rx_wr_beat_r and the index advances.  The buffer holds a
  --     full EP0 HS MaxPacket (64 B = 8 x 64-bit beats = 16 x 32-bit words).
  --   * Total byte count: pie_rx_nbytes is the WHOLE-packet byte count, but
  --     the PIE only registers it at packet end (set_rx_nbytes at crc16-valid,
  --     coincident with pie_endtransfer for the DATA stage; see
  --     usb_pie.m.vhdl:2860/3528).  It is therefore NOT valid at the first
  --     beat; the arbiter latches it (rx_total_r) on the DATA-stage
  --     pie_endtransfer pulse, when it authoritatively holds the total.
  --   * DRAIN: 32-bit words stream to ctrl_out_* at ctrl_out_rdy pace.  Word0
  --     = beat[31:0], word1 = beat[63:32] (little-endian, lowest OCP offset in
  --     the lowest lane).  The final word's ctrl_out_be reflects the partial
  --     byte count and ctrl_out_last marks the last valid word.
  --   * ctrl_xfer_done for the OUT data stage is sourced from rx_drain_done_r
  --     (drain complete), NOT the DATA-stage pie_endtransfer, so ctrl_decode
  --     consumes every buffered word before the transfer is finalized.
  --   * Buffer/indices/active flushed on claim release or a fresh SETUP.
  --
  -- Scope: a single MaxPacket (<= 64 bytes).  All current OCP recovery OUT
  -- commands fit one EP0 HS packet (INDIRECT_FIFO_DATA = 64 bytes is the max).
  -- Multi-packet OUT (wLength > 64) is OUT OF SCOPE for this milestone.
  -- ----------------------------------------------------------------------
  constant RX_MAXBYTES : integer := 64;                       -- EP0 HS MaxPacket
  constant RX_NBEATS   : integer := RX_MAXBYTES / BYTES_PER_BEAT; -- 8 beats
  constant RX_NWORDS   : integer := RX_MAXBYTES / 4;             -- 16 words

  type t_rx_buf is array (0 to RX_NBEATS-1)
                     of std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_buf_r          : t_rx_buf;
  signal rx_wr_beat_r      : unsigned(3 downto 0);  -- beat write index 0..8
  signal rx_rd_widx_r      : unsigned(4 downto 0);  -- word read index 0..16
  signal rx_total_r        : unsigned(11 downto 0); -- staged OUT bytes
  signal rx_drain_active_r : std_logic;             -- buffer -> ctrl_decode
  signal rx_drain_done_r   : std_logic;             -- 1-cycle finalize pulse

  signal rx_last_word_c    : std_logic;             -- current word is last
  signal ctrl_out_data_c   : std_logic_vector(31 downto 0);
  signal ctrl_out_be_c     : std_logic_vector(3 downto 0);
  signal ctrl_out_vld_c    : std_logic;
  signal ctrl_out_last_c   : std_logic;

  -- ----------------------------------------------------------------------
  -- Control-IN store-and-forward buffer.
  --
  -- A full EP0 high-speed MaxPacket buffer (64 bytes = 8 x 64-bit beats =
  -- 16 x 32-bit words) is required because the PIE can drain the packet at the
  -- HS wire rate while ctrl_decode is still producing later words.  The buffer
  -- stages the entire response before the data phase is activated, so the PIE
  -- never fetches an empty beat and never underruns the packet.
  -- The arbiter:
  --   * accumulates the 32-bit ctrl_decode words (respecting ctrl_in_be on
  --     the final partial word; little-endian, lowest OCP offset byte in the
  --     lowest byte lane -- mapping preserved) into tx_buf_r while HOLDING
  --     the PIE data phase inactive (epinfo_to_pie_active = '0') so the PIE
  --     NAKs any host IN token that arrives before the whole response is
  --     buffered (USB 2.0 Sec 8.5.3.2 / Sec 8.4.5: a device NAKs an IN token
  --     when it is not yet able to return the data).  This is the spec-
  --     compliant way to win the SETUP->IN race for a multi-beat response;
  --   * marks staging complete (tx_resp_ready_r) when ctrl_decode asserts
  --     ctrl_in_last (true end-of-data; the SV short-packet end is handled in
  --     usb_ocp_recovery_ctrl_decode.sv).  On completion it activates the PIE
  --     data phase and drives epinfo_to_pie_nbytes from the ACTUAL staged
  --     byte count (tx_nbytes_r), NOT wLength -- so a short command such as
  --     PROT_CAP (16 real bytes for a 64-byte request) emits a correct short
  --     packet, which the host accepts as end-of-data;
  --   * feeds the buffered beats to the PIE on pie_txdata_fetched.  Because
  --     the buffer is fully populated before activation, no beat can ever be
  --     late, so the underrun is impossible by construction.
  --   * resets the buffer, the word/byte counters and the active-gate on
  --     claim release (or a fresh SETUP) so the next transfer starts clean.
  --
  -- Scope: a single MaxPacket (<= 64 bytes).  All current OCP recovery IN
  -- responses fit one EP0 HS packet (DEVICE_STATUS = 64 bytes is the max).
  -- Multi-packet IN (wLength > 64) is OUT OF SCOPE for this milestone.
  -- ----------------------------------------------------------------------
  constant TX_MAXBYTES : integer := 64;                       -- EP0 HS MaxPacket
  constant TX_NBEATS   : integer := TX_MAXBYTES / BYTES_PER_BEAT; -- 8 beats
  constant TX_NWORDS   : integer := TX_MAXBYTES / 4;              -- 16 words

  type t_tx_buf is array (0 to TX_NBEATS-1)
                     of std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_buf_r          : t_tx_buf;
  signal tx_wr_widx_r      : unsigned(4 downto 0);  -- word write index 0..16
  signal tx_nbytes_r       : unsigned(6 downto 0);  -- staged bytes 0..64
  signal tx_resp_ready_r   : std_logic;             -- whole response staged
  signal tx_rd_beat_r      : unsigned(3 downto 0);  -- beat read index 0..8
  signal xfer_dir_in_r     : std_logic;             -- latched SETUP IN dir

  signal ctrl_in_rdy_c     : std_logic;
  signal tx_staged_beats_c : unsigned(3 downto 0);  -- ceil(tx_nbytes/8)
  signal tx_in_data_c      : std_logic;             -- claim & S_DATA & dir=IN & data pkt
  signal tx_beat_valid_c   : std_logic;             -- current beat has data

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
        -- Latch the transfer direction so the TX active gate knows
        -- whether the upcoming DATA stage is an IN (device->host) response
        -- that must be fully staged before the PIE is activated.
        xfer_dir_in_r <= setup_dir_in_c;
        -- Pre-filtered SETUP-vld pulse delivered to SV ctrl_decode only
        -- when this SETUP matches the OCP class; the SV side therefore
        -- never sees a standard or unrelated-class SETUP.
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
                                 nbytes_r, rx_drain_active_r, status_end_pend_r,
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
              and (rx_drain_active_r = '0') then
          -- Hold ownership until the OUT RX buffer has fully drained to
          -- ctrl_decode (rx_drain_active_r='0').  For IN transfers the drain
          -- never activates so this reduces to the plain pie_endtransfer
          -- release.  status_end_pend_r captures a STATUS-end pulse that
          -- arrives while the drain is still in flight.
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
      -- OUT RX buffer is still draining, so the S_STATUS->S_IDLE release is
      -- deferred until the drain completes.  Cleared on leaving S_STATUS.
      if claim_state_r = S_STATUS then
        if (pie_endtransfer_pulse_c = '1') and (rx_drain_active_r = '1') then
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
  --     pie_endtransfer rising edge, BUT only once the response is fully
  --     staged (tx_resp_ready_r='1').  A 64-byte IN read takes ~800 ns to
  --     stage; the host's first IN token can arrive mid-staging, and the
  --     PIE legitimately NAKs it (NAK raises pie_endtransfer).  Without the
  --     tx_resp_ready_r qualifier that NAK edge would fire ctrl_xfer_done
  --     and trip ctrl_decode's early-termination escape, abandoning staging
  --     to S_IDLE so the response never completes (the PIE then NAKs every
  --     retry -> host reads zeros).  Gating on tx_resp_ready_r lets staging
  --     finish across the NAK retries; a later IN then delivers the full
  --     response.  tx_resp_ready_r stays high through the STATUS stage.
  --   * OUT transfers (xfer_dir_in_r='0'): the RX buffer drains to ctrl_decode
  --     AFTER the DATA-stage pie_endtransfer (the PIE delivers all beats then
  --     ends the stage).  Sourcing ctrl_xfer_done from the pie_endtransfer
  --     edge would abort ctrl_decode mid-drain.  Instead pulse from
  --     rx_drain_done_r, emitted when the last buffered word is accepted.
  -- ======================================================================
  ctrl_xfer_done <= rx_drain_done_r when (xfer_dir_in_r = '0')
                    else (pie_endtransfer and not pie_endtransfer_q and
                          tx_resp_ready_r)
                         when (claim_state_r = S_DATA) or
                              (claim_state_r = S_STATUS)
                    else '0';

  -- ======================================================================
  -- Control-OUT store-and-forward buffer (PIE 64b beats -> SV 32b words).
  --
  -- ctrl_out_* presents the word currently addressed by rx_rd_widx_r while a
  -- drain is in flight.  Word0 = beat[31:0], word1 = beat[63:32] (little-
  -- endian, lowest OCP offset byte in the lowest lane).  The final word's
  -- ctrl_out_be reflects the partial byte count and ctrl_out_last marks it.
  -- ======================================================================
  rxstream_comb_proc : process (rx_drain_active_r, rx_rd_widx_r, rx_total_r,
                                rx_buf_r)
    variable beat_v : integer range 0 to RX_NBEATS-1;
    variable word_v : std_logic_vector(31 downto 0);
    variable rem_v  : unsigned(11 downto 0);
  begin
    ctrl_out_data_c <= (others => '0');
    ctrl_out_be_c   <= (others => '0');
    ctrl_out_vld_c  <= '0';
    ctrl_out_last_c <= '0';
    rx_last_word_c  <= '0';

    if rx_drain_active_r = '1' then
      beat_v := to_integer(rx_rd_widx_r(3 downto 1));   -- 0..7 (widx / 2)
      if rx_rd_widx_r(0) = '0' then
        word_v := rx_buf_r(beat_v)(31 downto 0);
      else
        word_v := rx_buf_r(beat_v)(63 downto 32);
      end if;
      ctrl_out_data_c <= word_v;
      ctrl_out_vld_c  <= '1';

      -- Bytes still to drain from this word onward (rx_total_r - widx*4).
      rem_v := rx_total_r -
               to_unsigned(to_integer(rx_rd_widx_r) * 4, rem_v'length);

      -- Valid-byte mask for this word (final word may be partial).
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
  end process rxstream_comb_proc;

  -- Single clocked process for the OUT byte buffer: capture beats from the
  -- PIE, latch the total at the DATA-stage end, then advance the drain read
  -- index at ctrl_out_rdy pace.  Async active-low reset (IP convention).
  rxbuf_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      for i in 0 to RX_NBEATS-1 loop
        rx_buf_r(i) <= (others => '0');
      end loop;
      rx_wr_beat_r      <= (others => '0');
      rx_rd_widx_r      <= (others => '0');
      rx_total_r        <= (others => '0');
      rx_drain_active_r <= '0';
      rx_drain_done_r   <= '0';
    elsif rising_edge(clk) then
      rx_drain_done_r <= '0';   -- default: single-cycle finalize pulse low

      if (claim_q = '0') or (setup_capture_c = '1') then
        -- Flush at transfer boundary / fresh SETUP: no OUT word leaks across
        -- transfers and each new packet starts from an empty buffer.
        for i in 0 to RX_NBEATS-1 loop
          rx_buf_r(i) <= (others => '0');
        end loop;
        rx_wr_beat_r      <= (others => '0');
        rx_rd_widx_r      <= (others => '0');
        rx_total_r        <= (others => '0');
        rx_drain_active_r <= '0';
      else
        -- CAPTURE: latch each incoming OUT data beat (claim held, NOT a SETUP
        -- beat, not yet draining).  The write index is guarded against the
        -- buffer depth so the trailing PIE CRC pulse (an extra pie_rxdatavalid
        -- that the PIE emits past the last data beat for multiple-of-8
        -- payloads) cannot write past the 8-beat buffer.
        if (pie_rxdatavalid = '1') and (pie_epinfo_setup = '0') and
           (rx_drain_active_r = '0') and
           (rx_wr_beat_r < to_unsigned(RX_NBEATS, rx_wr_beat_r'length)) then
          rx_buf_r(to_integer(rx_wr_beat_r(2 downto 0))) <= pie_rxdata;
          rx_wr_beat_r <= rx_wr_beat_r + 1;
        end if;

        -- CAPTURE COMPLETE: at the DATA-stage end (OUT direction) pie_rx_nbytes
        -- authoritatively holds the whole-packet byte count (the PIE registers
        -- it at crc16-valid, coincident with this pie_endtransfer).  Latch the
        -- total and start the drain.  A zero-byte data stage cannot occur (the
        -- FSM only enters S_DATA for wLength>0); guard it anyway by finalizing
        -- ctrl_decode without draining.
        if (pie_endtransfer_pulse_c = '1') and (claim_state_r = S_DATA) and
           (xfer_dir_in_r = '0') and (rx_drain_active_r = '0') then
          if unsigned(pie_rx_nbytes) /= 0 then
            rx_total_r        <= unsigned(pie_rx_nbytes);
            rx_drain_active_r <= '1';
            rx_rd_widx_r      <= (others => '0');
          else
            rx_drain_done_r <= '1';
          end if;
        end if;

        -- DRAIN: advance one 32-bit word per ctrl_out_rdy.  On the last word
        -- drop active and emit the single-cycle finalize pulse.
        if (rx_drain_active_r = '1') and (ctrl_out_rdy = '1') then
          if rx_last_word_c = '1' then
            rx_drain_active_r <= '0';
            rx_drain_done_r   <= '1';
          else
            rx_rd_widx_r <= rx_rd_widx_r + 1;
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
  -- Control-IN store-and-forward buffer (SV 32b words -> PIE 64b beats).
  --
  -- ctrl_in_rdy accepts a new 32-bit word while the arbiter holds claim, the
  -- response is not yet fully staged (tx_resp_ready_r='0'), and the 64-byte
  -- buffer is not full (tx_wr_widx_r < TX_NWORDS).  Unused byte lanes of a
  -- partial final word are masked to 0 for X-hygiene; the actual staged byte
  -- count (tx_nbytes_r) is what the PIE is told via epinfo_to_pie_nbytes, so
  -- those padding lanes are never placed on the wire.
  -- ======================================================================
  ctrl_in_rdy_c <= '1' when (claim_q = '1') and (tx_resp_ready_r = '0') and
                            (tx_wr_widx_r < to_unsigned(TX_NWORDS, 5))
                   else '0';
  ctrl_in_rdy   <= ctrl_in_rdy_c;

  -- Number of resident 64-bit beats = ceil(tx_nbytes_r / 8).
  tx_staged_beats_c <= resize(shift_right(tx_nbytes_r +
                                          to_unsigned(BYTES_PER_BEAT-1, 7), 3),
                              4);

  -- A claimed IN DATA stage that is still draining staged beats to the PIE.
  -- Excludes the terminating-ZLP phase so the data-path muxes (nbytes) select
  -- the zero-length values for that packet rather than the 64-byte data values.
  tx_in_data_c <= '1' when (claim_q = '1') and
                           (claim_state_r = S_DATA) and
                           (xfer_dir_in_r = '1') and
                           (zlp_phase_r = '0')
                  else '0';

  -- Terminating-ZLP owed: an IN read (xfer_dir_in_r) whose whole response is
  -- staged (tx_resp_ready_r) and exactly fills one EP0 MaxPacket
  -- (tx_nbytes_r = TX_MAXBYTES).  Such an exact-multiple data stage cannot be
  -- terminated by a short packet, so it requires a zero-length terminator
  -- carrying the alternated toggle (USB 2.0 Sec 5.5.3 / 8.5.3.2 / 8.6).
  zlp_owed_c <= '1' when (xfer_dir_in_r = '1') and
                         (tx_resp_ready_r = '1') and
                         (tx_nbytes_r = to_unsigned(TX_MAXBYTES, tx_nbytes_r'length))
                else '0';

  -- The beat currently presented to the PIE holds valid data iff the whole
  -- response is staged and the read index has not walked past the last beat.
  -- The buffer is fully populated before tx_resp_ready_r asserts, so a beat
  -- can never be requested late -> no underrun is possible by construction.
  tx_beat_valid_c <= '1' when (tx_resp_ready_r = '1') and
                              (tx_rd_beat_r < tx_staged_beats_c)
                     else '0';

  -- Single clocked process for the byte buffer (memory-style array write +
  -- read/write pointers).  Async active-low reset, matching the IP convention.
  txbuf_clk_proc : process (clk, reset_n)
    variable word_v : std_logic_vector(31 downto 0);
    variable nb_v   : integer range 0 to 4;
    variable beat_i : integer range 0 to TX_NBEATS-1;
  begin
    if reset_n = '0' then
      for i in 0 to TX_NBEATS-1 loop
        tx_buf_r(i) <= (others => '0');
      end loop;
      tx_wr_widx_r    <= (others => '0');
      tx_nbytes_r     <= (others => '0');
      tx_resp_ready_r <= '0';
      tx_rd_beat_r    <= (others => '0');
    elsif rising_edge(clk) then
      if (claim_q = '0') or (setup_capture_c = '1') then
        -- Flush at transfer boundary / fresh SETUP: nothing leaks across
        -- transfers and each new response starts from an empty buffer.
        for i in 0 to TX_NBEATS-1 loop
          tx_buf_r(i) <= (others => '0');
        end loop;
        tx_wr_widx_r    <= (others => '0');
        tx_nbytes_r     <= (others => '0');
        tx_resp_ready_r <= '0';
        tx_rd_beat_r    <= (others => '0');
      else
        -- Accept one 32-bit word from the SV side; mask invalid byte lanes
        -- and count the valid (contiguous, LSB-first) bytes it contributes.
        if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') then
          nb_v := 0;
          for b in 0 to 3 loop
            if ctrl_in_be(b) = '1' then
              word_v(b*8 + 7 downto b*8) := ctrl_in_data(b*8 + 7 downto b*8);
              nb_v := nb_v + 1;
            else
              word_v(b*8 + 7 downto b*8) := (others => '0');
            end if;
          end loop;

          beat_i := to_integer(tx_wr_widx_r(4 downto 1));
          if tx_wr_widx_r(0) = '0' then
            tx_buf_r(beat_i)(31 downto 0)  <= word_v;
          else
            tx_buf_r(beat_i)(63 downto 32) <= word_v;
          end if;

          tx_nbytes_r  <= tx_nbytes_r + to_unsigned(nb_v, 7);
          tx_wr_widx_r <= tx_wr_widx_r + 1;

          -- ctrl_in_last marks true end-of-data (incl. the SV short-packet
          -- terminating beat); the whole response is now resident.
          if ctrl_in_last = '1' then
            tx_resp_ready_r <= '1';
          end if;
        end if;

        -- Advance the read pointer as the PIE consumes staged beats.
        if (pie_txdata_fetched = '1') and (tx_resp_ready_r = '1') then
          tx_rd_beat_r <= tx_rd_beat_r + 1;
        end if;
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
  --                 toggle/disabled/iso 0, nbytes = latched wLength,
  --                 maxpacket = "11" (HS EP0 = 64 B), txdata from the
  --                 IN serializer slot.
  -- STALL OR-combine: legacy stall OR the SV-driven ctrl_set_stall (while
  --   claim_q) OR a collision-decline pulse (decline_pend_q).
  -- ======================================================================
  epinfo_to_pie_valid    <= legacy_epinfo_valid    when claim_q = '0' else '1';
  -- TX-staging active gate: for a claimed IN DATA stage the
  -- PIE data phase is held INACTIVE until the store-and-forward buffer holds
  -- the WHOLE response (tx_resp_ready_r='1').  While inactive the PIE NAKs any
  -- early host IN token (USB 2.0 Sec 8.5.3.2 / 8.4.5: NAK when not yet able to
  -- return the data), winning the SETUP->IN race for multi-beat responses.
  -- SETUP, OUT-DATA and STATUS stages keep the plain claimed-active semantics.
  epinfo_to_pie_active   <= legacy_epinfo_active when claim_q = '0'
                            else '0' when (tx_in_data_c = '1') and
                                          (tx_resp_ready_r = '0')
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
  --   * IN DATA stage  -> ACTUAL staged byte count (tx_nbytes_r), NOT wLength,
  --     so short commands emit a correct short packet.
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
                              else std_logic_vector(resize(tx_nbytes_r, 15))
                              when tx_in_data_c = '1'
                              else std_logic_vector(nbytes_r);
  -- HS EP0 is a control endpoint with MaxPacketSize 64: encoding "00"
  -- (usb_pie.m.vhdl packetsize(): "00" => v_maxpacket=64 for HS Control).
  -- "11" would select the HS iso/interrupt 1024 budget and also mis-set the
  -- epinfo_maxpacket(1) iso/interrupt classifier used by the OUT handshake.
  epinfo_to_pie_maxpacket<= legacy_epinfo_maxpacket when claim_q = '0' else "00";
  epinfo_to_pie_txdata   <= legacy_epinfo_txdata
                              when claim_q = '0'
                              else tx_buf_r(to_integer(tx_rd_beat_r(2 downto 0)));
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
      -- True overflow check: an OUT data stage whose latched byte count
      -- exceeds the 64-byte buffer is unsupported (a >64 B single packet
      -- cannot occur on EP0 HS MaxPacket=64; multi-packet OUT is future
      -- work).  Analogous to the TX "word accepted while buffer full" check:
      -- it flags a genuine out-of-scope condition rather than the (now legal)
      -- back-to-back beat arrival that the store-and-forward buffer absorbs.
      assert not ((rx_drain_active_r = '1') and
                  (rx_total_r > to_unsigned(RX_MAXBYTES, rx_total_r'length)))
        report "usb_pie_recovery_arb: OUT byte count exceeds 64B buffer (>MaxPacket OUT unsupported)"
        severity failure;

      -- True overflow check: ctrl_in_vld accepted while the staging buffer
      -- is already full (must be unreachable by construction since
      -- ctrl_in_rdy_c de-asserts once tx_wr_widx_r reaches TX_NWORDS).
      assert not ((ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') and
                  (tx_wr_widx_r >= to_unsigned(TX_NWORDS, 5)))
        report "usb_pie_recovery_arb: word accepted while buffer full -- arbiter bug"
        severity failure;

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
