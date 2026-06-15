--  SPDX-License-Identifier: Apache-2.0
--  ----------------------------------------------------------------------------
--  File: usb_pie_recovery_arb.m.vhdl
--
--  Architecture: behavioural
--
--  Microarchitecture
--  -----------------
--  Data plane:
--    1. SETUP capture: pie_rxdata[63:0] is sampled on the cycle that
--       (pie_epinfo_setup AND pie_rxdatavalid) is asserted.  USB 2.0 Section
--       8.5.3 mandates an 8-byte SETUP payload and the PIE drains it in a
--       single 64-bit beat (pie_rx_nbytes = 12'd8).  setup_pkt_vld is
--       pulsed for one cycle the same beat.
--
--    2. Control-OUT serializer: pie_rxdata words are decomposed into bytes
--       and presented on ctrl_out_data with ctrl_out_vld; advances on
--       ctrl_out_rdy.  pie_rx_nbytes drives the last-byte tag.  Width
--       64 -> 8: one beat consumed each USB_DATAWIDTH/8 = 8 byte-cycles.
--
--    3. Control-IN serializer: 8-byte slots are accumulated from
--       ctrl_in_data and flushed to epinfo_to_pie_txdata when full (or on
--       ctrl_in_last).  pie_txdata_fetched advances PIE through the IN
--       payload one 64-bit beat at a time.
--
--  Control plane:
--    Single arbiter mux + EP-tag filter.  rec_claim must be high while
--    recovery owns the in-flight EP0 transaction; ctrl_xfer_done re-emits
--    pie_endtransfer to the SV layer.  Default (rec_claim=0) is a pure
--    pass-through: legacy_epinfo_* go to epinfo_to_pie_* unmodified, so
--    pre-recovery USB behaviour is bit-identical to the un-arbitered IP.
--
--  Reuse:
--    No counters that exist elsewhere.  rx_byte_idx_r and tx_byte_idx_r
--    are 3-bit (byte position within a 64-bit beat).  rx_remaining_r is
--    12-bit (matches pie_rx_nbytes width).  No bit duplicates a PIE FSM
--    output.
--  ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture rtl of usb_pie_recovery_arb is

  -- ----------------------------------------------------------------------
  -- Helpers / constants
  -- ----------------------------------------------------------------------
  constant BYTES_PER_BEAT : integer := USB_DATAWIDTH / 8;  -- 8 for 64b PIE
  constant REC_EPNR_SLV   : std_logic_vector(3 downto 0) :=
                            std_logic_vector(to_unsigned(C_REC_EPNR, 4));

  -- ----------------------------------------------------------------------
  -- EP-tag classification: is the in-flight PIE transaction owned by the
  -- recovery endpoint?  EP0-only filter (matches plan D0.A).
  -- ----------------------------------------------------------------------
  signal is_rec_ep_c : std_logic;
  signal arb_owns_c  : std_logic;  -- arbiter is overriding pie inputs

  -- Combinational OCP class-match on pie_rxdata during setup_capture_c.
  -- Latched into setup_is_ocp_match_q so the gating term holds high for
  -- the entire pie_epinfo_setup_received pulse, which trails
  -- setup_capture_c by ~10s-100s of ns (FSDB-confirmed in
  -- research/usb_ocp_p7_gate_debug.md). rec_claim_q (one PIE clk late)
  -- alone is too narrow to cover the leading edge.
  signal setup_is_ocp_match_c : std_logic;
  signal setup_is_ocp_match_q : std_logic;
  signal pie_setup_received_r : std_logic;
  -- Tracks whether the SETUP-stage pie_endtransfer has already been
  -- observed and consumed within the current claim window. First
  -- pie_endtransfer after arb_owns_c rises is provably the SETUP-end
  -- (USB 2.0 Sec 8.5.3 - DATA cannot complete before SETUP); we skip
  -- it. Subsequent pie_endtransfer pulses forward to ctrl_xfer_done.
  signal setup_end_seen_q : std_logic;

  -- ----------------------------------------------------------------------
  -- SETUP capture (one cycle latch when PIE delivers the SETUP beat).
  -- ----------------------------------------------------------------------
  signal setup_capture_c : std_logic;
  signal setup_pkt_r     : std_logic_vector(63 downto 0);
  signal setup_pkt_vld_r : std_logic;

  -- ----------------------------------------------------------------------
  -- Control-OUT 64b -> 8b serializer (deserializer of PIE rxdata).
  -- ----------------------------------------------------------------------
  signal rx_word_r        : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_byte_idx_r    : unsigned(2 downto 0);  -- 0..7, 3 bits
  signal rx_remaining_r   : unsigned(11 downto 0); -- bytes still to drain
  signal rx_active_r      : std_logic;

  signal rx_word_nxt      : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal rx_byte_idx_nxt  : unsigned(2 downto 0);
  signal rx_remaining_nxt : unsigned(11 downto 0);
  signal rx_active_nxt    : std_logic;

  signal ctrl_out_data_c  : std_logic_vector(7 downto 0);
  signal ctrl_out_vld_c   : std_logic;
  signal ctrl_out_last_c  : std_logic;

  -- ----------------------------------------------------------------------
  -- Control-IN 8b -> 64b serializer (serializer of ctrl_in into 64b beats).
  -- ----------------------------------------------------------------------
  signal tx_word_r        : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_byte_idx_r    : unsigned(2 downto 0);  -- next free byte slot
  signal tx_word_full_r   : std_logic;             -- one beat ready
  signal tx_last_r        : std_logic;             -- last-beat marker

  signal tx_word_nxt      : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal tx_byte_idx_nxt  : unsigned(2 downto 0);
  signal tx_word_full_nxt : std_logic;
  signal tx_last_nxt      : std_logic;

  signal ctrl_in_rdy_c    : std_logic;

  -- ----------------------------------------------------------------------
  -- Per-transfer byte budget latched from SETUP wLength.  Driven into
  -- mux_nbytes_c so the PIE TX serializer (usb_pie.m.vhdl) is told the
  -- full data-stage length rather than the previous placeholder of 8.
  --
  -- Spec citations:
  --   OCP Recovery v1.1 Sec 8.5.1: data-stage byte count equals the
  --     wLength carried by the SETUP packet.
  --   USB 2.0 Sec 9.3 (Table 9-2): wLength is little-endian at bytes 6..7
  --     of the SETUP payload.  setup_pkt_r is packed byte 0 at bits[7:0],
  --     byte k at bits[8k+7:8k]; therefore wLength low = bits(55:48),
  --     wLength high = bits(63:56).
  --   USB 2.0 Sec 5.5.3: control transfer data stage may be terminated
  --     early by a short packet; sending fewer than wLength bytes when the
  --     register is shorter is permitted.
  --
  -- Width: USB wLength is 16 bits but the PIE nbytes port is 15 bits.
  -- OCP Recovery v1.1 register payloads are all <= 256 bytes, so dropping
  -- the MSB cannot truncate any spec-legal recovery transfer.
  -- ----------------------------------------------------------------------
  signal nbytes_r        : unsigned(14 downto 0);

  -- ----------------------------------------------------------------------
  -- Arbiter mux outputs (combinational view of muxed epinfo to PIE).
  -- ----------------------------------------------------------------------
  signal mux_valid_c        : std_logic;
  signal mux_active_c       : std_logic;
  signal mux_disabled_c     : std_logic;
  signal mux_toggle_c       : std_logic;
  signal mux_stall_c        : std_logic;
  signal mux_iso_c          : std_logic;
  signal mux_nbytes_c       : std_logic_vector(14 downto 0);
  signal mux_maxpacket_c    : std_logic_vector(1 downto 0);
  signal mux_txdata_c       : std_logic_vector(USB_DATAWIDTH-1 downto 0);
  signal mux_txdata_valid_c : std_logic;

begin

  -- ======================================================================
  -- EP-tag classification (combinational, no flop)
  -- ======================================================================
  is_rec_ep_c <= '1' when (pie_epinfo_epnr = REC_EPNR_SLV) else '0';
  arb_owns_c  <= rec_claim and is_rec_ep_c;

  -- ======================================================================
  -- Legacy SIE SETUP-received gating
  --
  -- Per FSDB evidence in research/usb_ocp_p7_claim_debug.md, the legacy
  -- IP-3511 PIE delivers pie_epinfo_setup_received directly into the
  -- usb_synchronizer/usb_reg_if path that drives DEVCMDSTAT.SETUP and
  -- INTSTAT.EP0OUT. That notification is what kicks the MCU EPCS into
  -- decoding the SETUP. If the SETUP is an OCP recovery class request
  -- the MCU MUST NOT see the SETUP -- otherwise both the SV recovery
  -- decoder and the MCU firmware race to respond on the same EP0
  -- transfer, corrupting the IN data stage (host sees ZLP from MCU
  -- instead of PROT_CAP bytes from the SV decoder).
  --
  -- Gating must fire on the SAME clock as the SETUP arrival (rec_claim
  -- only rises one PIE clk AFTER the SETUP via the SV-side flop, which
  -- is too late -- the legacy SIE has already latched the
  -- setup_received pulse by then). We therefore decode the OCP class
  -- match combinationally from pie_rxdata while setup_capture_c='1'
  -- and OR that with the (cycle-late) arb_owns_c term so the gate
  -- holds high for the entire claimed transfer.
  --
  -- Class-match rule per OCP Recovery v1.1 Sec 8.5.1:
  --   bmRequestType[6:5] == "01"      (Class)
  --   bmRequestType[4:0] == "00001"   (Interface recipient)
  --   bRequest           == 8'h00     (OCP_RECOVERY_TRANSFER)
  --   wIndex[7:0]        == REC_IFACE_NUM (this build: 8'h00)
  --
  -- pie_rxdata little-endian SETUP byte layout (USB 2.0 Sec 9.3 Tbl 9-2):
  --   bmRequestType = rxdata[7:0]
  --   bRequest      = rxdata[15:8]
  --   wValue        = rxdata[31:16]
  --   wIndex        = rxdata[47:32]    (lo byte 39:32)
  --   wLength       = rxdata[63:48]
  --
  -- USB 2.0 Sec 8.5.3 wire behavior is preserved: the arbiter still
  -- consumes the SETUP and answers the data/status phases via the muxed
  -- epinfo_to_pie_* path. Only the *internal* MCU notification is
  -- suppressed for recovery-class SETUPs.
  -- ======================================================================
  setup_is_ocp_match_c <= '1' when (setup_capture_c = '1')
                                  and (pie_rxdata(6 downto 5)  = "01")
                                  and (pie_rxdata(4 downto 0)  = "00001")
                                  and (pie_rxdata(15 downto 8) = "00000000")
                                  and (pie_rxdata(39 downto 32) = std_logic_vector(to_unsigned(0, 8)))
                              else '0';

  -- Hold the OCP-match flag from SETUP capture through the entire
  -- pie_epinfo_setup_received pulse. FSDB evidence
  -- (research/usb_ocp_p7_gate_debug.md): pie_epinfo_setup_received
  -- trails setup_capture_c by ~117 ns and remains high for ~680 ns.
  -- Iter 7 attempt cleared the flop whenever pie_epinfo_setup_received='0'
  -- which immediately fires in the gap between capture and pulse rise
  -- (research/usb_ocp_p7_datapath.md, Q1). Clear only on the FALLING
  -- edge of pie_epinfo_setup_received to guarantee the flop overlaps
  -- the entire pulse.
  setup_match_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      setup_is_ocp_match_q     <= '0';
      pie_setup_received_r     <= '0';
    elsif rising_edge(clk) then
      pie_setup_received_r <= pie_epinfo_setup_received;
      if setup_is_ocp_match_c = '1' then
        setup_is_ocp_match_q <= '1';
      elsif (pie_setup_received_r = '1') and (pie_epinfo_setup_received = '0') then
        -- Falling edge of pulse: now safe to drop the match marker.
        setup_is_ocp_match_q <= '0';
      end if;
    end if;
  end process setup_match_clk_proc;

  legacy_setup_received_gated <= pie_epinfo_setup_received and
                                 (not setup_is_ocp_match_c) and
                                 (not setup_is_ocp_match_q) and
                                 (not arb_owns_c);

  -- ======================================================================
  -- SETUP capture
  --
  -- USB 2.0 Section 8.5.3: SETUP is an 8-byte payload. The PIE delivers
  -- this single 64-bit beat with pie_epinfo_setup high and pie_rxdatavalid
  -- asserted.  Single-beat: no width adaptation needed.
  -- ======================================================================
  setup_capture_c <= pie_epinfo_setup and pie_rxdatavalid;

  setup_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      setup_pkt_r     <= (others => '0');
      setup_pkt_vld_r <= '0';
      nbytes_r        <= (others => '0');
    elsif rising_edge(clk) then
      setup_pkt_vld_r <= setup_capture_c;
      if setup_capture_c = '1' then
        setup_pkt_r <= pie_rxdata;
        -- USB 2.0 Sec 9.3 Tbl 9-2: wLength little-endian at bytes 6..7.
        -- Concatenate high byte (bits 63:56) with low byte (bits 55:48)
        -- and truncate to 15-bit nbytes width.  See nbytes_r declaration
        -- comment for the truncation rationale.
        nbytes_r <= unsigned(pie_rxdata(62 downto 48));
      end if;
    end if;
  end process setup_clk_proc;

  setup_pkt     <= setup_pkt_r;
  setup_pkt_vld <= setup_pkt_vld_r;

  -- ======================================================================
  -- Control-OUT byte stream (deserializer)
  --
  -- Whenever PIE delivers an RX beat AND recovery owns EP0 OUT (not setup),
  -- latch the beat and drain one byte per ctrl_out_rdy.  pie_rx_nbytes is
  -- captured into rx_remaining_r and decremented per byte; ctrl_out_last
  -- pulses when the final byte is on the wire.
  --
  -- The PIE never delivers a second RX beat before the first is consumed
  -- because the recovery transactions are short (control transfers; <=
  -- 512 bytes per record per OCP v1.1).  We assert this; if the assertion
  -- fires, an extra latency buffer is required.
  -- ======================================================================
  rxstream_comb_proc : process (rx_word_r, rx_byte_idx_r, rx_remaining_r,
                                rx_active_r, pie_rxdata, pie_rxdatavalid,
                                pie_rx_nbytes, pie_epinfo_setup, arb_owns_c,
                                ctrl_out_rdy)
    variable byte_index_v : integer range 0 to 7;
    variable take_v       : std_logic;
  begin
    -- Defaults
    rx_word_nxt      <= rx_word_r;
    rx_byte_idx_nxt  <= rx_byte_idx_r;
    rx_remaining_nxt <= rx_remaining_r;
    rx_active_nxt    <= rx_active_r;
    ctrl_out_vld_c   <= '0';
    ctrl_out_last_c  <= '0';
    ctrl_out_data_c  <= (others => '0');

    -- Latch incoming RX beat (only when recovery owns EP0 and it is NOT
    -- a setup payload; setup is consumed separately by the setup_capture).
    if (pie_rxdatavalid = '1') and (arb_owns_c = '1') and
       (pie_epinfo_setup = '0') and (rx_active_r = '0') then
      rx_word_nxt      <= pie_rxdata;
      rx_byte_idx_nxt  <= (others => '0');
      rx_remaining_nxt <= unsigned(pie_rx_nbytes);
      if unsigned(pie_rx_nbytes) /= 0 then
        rx_active_nxt <= '1';
      end if;
    end if;

    -- Drain one byte per accepted ctrl_out_rdy cycle.
    if rx_active_r = '1' then
      byte_index_v := to_integer(rx_byte_idx_r);
      ctrl_out_data_c <= rx_word_r(byte_index_v*8 + 7 downto byte_index_v*8);
      ctrl_out_vld_c  <= '1';
      if rx_remaining_r = to_unsigned(1, rx_remaining_r'length) then
        ctrl_out_last_c <= '1';
      end if;
      take_v := ctrl_out_rdy;
      if take_v = '1' then
        rx_remaining_nxt <= rx_remaining_r - 1;
        if rx_remaining_r = to_unsigned(1, rx_remaining_r'length) then
          rx_active_nxt <= '0';
        elsif rx_byte_idx_r = "111" then
          -- Word exhausted but more bytes pending: in EP0-only the next
          -- RX beat arrives next cycle.  Counter wraps.
          rx_byte_idx_nxt <= (others => '0');
        else
          rx_byte_idx_nxt <= rx_byte_idx_r + 1;
        end if;
      end if;
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
  -- Control-IN byte stream (serializer)
  --
  -- Pack ctrl_in_data bytes into a 64-bit slot; expose tx_word_r on
  -- epinfo_to_pie_txdata when slot is full or ctrl_in_last asserted.
  -- pie_txdata_fetched pops one 64-bit beat; on pop, slot is invalidated
  -- and ready to accept next 8 bytes.
  --
  -- Backpressure: ctrl_in_rdy = !tx_word_full_r so the SV layer cannot
  -- overflow the slot while PIE has not yet fetched.
  -- ======================================================================
  -- Fix 3c (usb_ocp_arbiter_fix_plan Bug 3): gate ctrl_in_rdy on arb_owns_c
  -- so the SV ctrl_decode source observes backpressure the instant the
  -- arbiter releases EP0 (e.g. on a stray pie_endtransfer pulse).  This
  -- works with the global ctrl_xfer_done escape in ctrl_decode.sv to
  -- ensure the SV FSM exits S_READ instead of wedging on a full slot.
  -- USB 2.0 Sec 8.5.3.2: control transfer state must not leak across
  -- transfer boundaries.
  ctrl_in_rdy_c <= (not tx_word_full_r) and arb_owns_c;
  ctrl_in_rdy   <= ctrl_in_rdy_c;

  txstream_comb_proc : process (tx_word_r, tx_byte_idx_r, tx_word_full_r,
                                tx_last_r, ctrl_in_data, ctrl_in_vld,
                                ctrl_in_last, ctrl_in_rdy_c, pie_txdata_fetched,
                                arb_owns_c)
    variable byte_index_v : integer range 0 to 7;
  begin
    -- Defaults
    tx_word_nxt      <= tx_word_r;
    tx_byte_idx_nxt  <= tx_byte_idx_r;
    tx_word_full_nxt <= tx_word_full_r;
    tx_last_nxt      <= tx_last_r;

    -- Accept one byte from SV side.  Fix 3b (usb_ocp_arbiter_fix_plan
    -- Bug 3): require arb_owns_c='1' so stray bytes pushed after PIE
    -- has issued pie_endtransfer cannot leak into the slot for the
    -- next transaction.  (ctrl_in_rdy_c is already gated on arb_owns_c
    -- above, but defensive gating here protects against a same-cycle
    -- race where the SV side asserts vld on the cycle arb_owns drops.)
    if (ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') and
       (arb_owns_c = '1') then
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

    -- Drain a full beat when PIE fetches it.  Only one beat is held; PIE
    -- pulses pie_txdata_fetched after consuming epinfo_to_pie_txdata.
    if (pie_txdata_fetched = '1') and (tx_word_full_r = '1') and
       (arb_owns_c = '1') then
      tx_word_full_nxt <= '0';
      tx_last_nxt      <= '0';
      tx_word_nxt      <= (others => '0');
    end if;

    -- Fix 3a (usb_ocp_arbiter_fix_plan Bug 3): flush the staging slot
    -- whenever the arbiter is not claiming EP0.  Placed AFTER the
    -- accept/drain blocks so it dominates both.  Without this, a
    -- premature pie_endtransfer that drops rec_claim mid-DATA-IN
    -- leaves tx_word_full_r='1' forever (drain requires arb_owns_c='1',
    -- but arb_owns_c is now '0'), wedging the slot into the next
    -- recovery transaction.  Matches the rec_claim=0 pass-through
    -- architecture in the header.
    -- OCP Recovery v1.1 Sec 8.5 / USB 2.0 Sec 8.5.3.2: each control
    -- transfer is atomic; arbiter state must not leak across transfer
    -- boundaries.
    if arb_owns_c = '0' then
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
  -- xfer-done re-emission to SV layer (gated by claim so we do not surface
  -- legacy EP completions to the recovery decoder).
  --
  -- IMPORTANT: USB 2.0 Sec 8.5.3 control transfers have a SETUP stage,
  -- then DATA stage (optional, possibly multiple data packets), then
  -- STATUS stage. The PIE fires pie_endtransfer at the END of EACH
  -- stage. We must NOT forward the SETUP-stage pie_endtransfer to
  -- ctrl_xfer_done, otherwise the SV ctrl_decode FSM treats it as
  -- "transfer over" and clears rec_claim before the DATA stage starts
  -- (research/usb_ocp_p7_datapath.md Q2). Iter-8 used
  -- data_stage_seen_q with the heuristic "DATA stage begun when
  -- ctrl_in_vld asserted"; FSDB (research/usb_ocp_p7_prot_cap.md)
  -- showed ctrl_in_vld rises ~33 ns BEFORE the SETUP-stage
  -- pie_endtransfer pulse, so the gate is already open. Switch to a
  -- direct count: the FIRST pie_endtransfer after arb_owns_c rises is
  -- provably the SETUP-stage end (DATA cannot complete before SETUP
  -- completes); subsequent pulses legitimately mark DATA / STATUS end.
  -- ======================================================================
  setup_end_clk_proc : process (clk, reset_n)
  begin
    if reset_n = '0' then
      setup_end_seen_q <= '0';
    elsif rising_edge(clk) then
      if arb_owns_c = '0' then
        -- Inter-transfer: reset for the next transfer's SETUP stage.
        setup_end_seen_q <= '0';
      elsif (pie_endtransfer = '1') and (setup_end_seen_q = '0') then
        -- First pie_endtransfer after claim = SETUP-stage end. Mark
        -- seen so any subsequent pie_endtransfer pulses forward to
        -- ctrl_xfer_done as legitimate DATA/STATUS-end markers.
        setup_end_seen_q <= '1';
      end if;
    end if;
  end process setup_end_clk_proc;

  ctrl_xfer_done <= pie_endtransfer when (arb_owns_c = '1') and (setup_end_seen_q = '1') else '0';

  -- ======================================================================
  -- EP-info mux to PIE.
  --
  -- When arb_owns_c = '0': pure pass-through of legacy bundle.  This is
  -- the default for the entire IP behaviour outside class-specific OCP
  -- recovery requests; pre-existing USB enumeration / standard-request
  -- handling is bit-identical.
  --
  -- When arb_owns_c = '1':
  --   - valid/active: assert (recovery EP is ready when claimed).
  --   - disabled/iso: 0 (control EP, not isochronous).
  --   - toggle: 0 today; OCP DATA0/1 toggling is handled inside ctrl_decode
  --     for the next phase; for now follow legacy default.
  --   - stall: OR-combine legacy with ctrl_set_stall (Section 9.4.5
  --     CLEAR_FEATURE handling stays with legacy; arbiter never clears).
  --   - nbytes / maxpacket: nbytes is the wLength captured from the SETUP
  --     packet (nbytes_r, see setup_clk_proc).  This replaces the prior
  --     hard-coded "8" placeholder which caused PIE to terminate the IN
  --     data stage after a single 8-byte beat regardless of wLength,
  --     truncating responses such as PROT_CAP (wLength=64).
  --     Spec: OCP Recovery v1.1 Sec 8.5.1 (data-stage length = wLength)
  --           and USB 2.0 Sec 5.5.3 (control transfer data stage budget).
  --     maxpacket is left at "11" (HS EP0, 64 B); FS support is deferred
  --     because the recovery interface currently mandates HS operation
  --     and changing this risks affecting non-recovery EP0 traffic.  See
  --     usb_ocp_arbiter_fix_plan.md Bug 5.
  --   - txdata / txdata_valid: from the IN serializer slot.
  -- ======================================================================
  mux_valid_c        <= legacy_epinfo_valid    when arb_owns_c = '0' else '1';
  mux_active_c       <= legacy_epinfo_active   when arb_owns_c = '0' else '1';
  mux_disabled_c     <= legacy_epinfo_disabled when arb_owns_c = '0' else '0';
  mux_toggle_c       <= legacy_epinfo_toggle   when arb_owns_c = '0' else '0';
  mux_iso_c          <= legacy_epinfo_iso      when arb_owns_c = '0' else '0';
  mux_nbytes_c       <= legacy_epinfo_nbytes
                          when arb_owns_c = '0'
                          else std_logic_vector(nbytes_r);
  mux_maxpacket_c    <= legacy_epinfo_maxpacket when arb_owns_c = '0' else "11";
  mux_txdata_c       <= legacy_epinfo_txdata
                          when arb_owns_c = '0' else tx_word_r;
  mux_txdata_valid_c <= legacy_epinfo_txdata_valid
                          when arb_owns_c = '0' else tx_word_full_r;

  -- STALL is OR-combined regardless of claim, so the SV layer can issue a
  -- STALL on EP0 (e.g. on a malformed class request) even if the legacy
  -- path also wants to stall a different EP simultaneously.  See OCP
  -- Recovery v1.1 Section 8.5: malformed class requests SHALL be STALLed.
  mux_stall_c <= legacy_epinfo_stall or (ctrl_set_stall and is_rec_ep_c);

  epinfo_to_pie_valid        <= mux_valid_c;
  epinfo_to_pie_active       <= mux_active_c;
  epinfo_to_pie_disabled     <= mux_disabled_c;
  epinfo_to_pie_toggle       <= mux_toggle_c;
  epinfo_to_pie_stall        <= mux_stall_c;
  epinfo_to_pie_iso          <= mux_iso_c;
  epinfo_to_pie_nbytes       <= mux_nbytes_c;
  epinfo_to_pie_maxpacket    <= mux_maxpacket_c;
  epinfo_to_pie_txdata       <= mux_txdata_c;
  epinfo_to_pie_txdata_valid <= mux_txdata_valid_c;

  -- ======================================================================
  -- Assertions (PSL/VHDL severity; ignored at synthesis).
  -- ======================================================================
  -- pragma translate_off
  assertions_proc : process (clk)
  begin
    if rising_edge(clk) and reset_n = '1' then
      -- A new RX beat arriving while previous beat is still being drained
      -- is unsupported (see microarch note).
      assert not ((pie_rxdatavalid = '1') and (arb_owns_c = '1') and
                  (pie_epinfo_setup = '0') and (rx_active_r = '1'))
        report "usb_pie_recovery_arb: back-to-back RX beats while draining"
        severity failure;

      -- pie_error during a recovery transaction: log but do not stop.
      if (pie_error = '1') and (arb_owns_c = '1') then
        report "usb_pie_recovery_arb: pie_error during recovery EP0 xfer"
          severity warning;
      end if;

      -- usb_ocp_arbiter_fix_plan Bug 2: the previous "ctrl_in_vld with
      -- tx slot full" warning fired every cycle on legitimate ready/valid
      -- backpressure (vld held high while rdy=0 is the standard contract,
      -- e.g. AXI-Stream TVALID/TREADY rule).  Replaced with a true-overflow
      -- check that should be unreachable because ctrl_in_rdy_c is the
      -- inverse of tx_word_full_r.
      assert not ((ctrl_in_vld = '1') and (ctrl_in_rdy_c = '1') and
                  (tx_word_full_r = '1'))
        report "usb_pie_recovery_arb: byte accepted while slot full -- arbiter bug"
        severity failure;
    end if;
  end process assertions_proc;
  -- pragma translate_on

end architecture rtl;
