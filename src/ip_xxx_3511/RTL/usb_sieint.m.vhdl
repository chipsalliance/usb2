--  ----------------------------------------------------------------------------
--                     Copyright Message
--  ----------------------------------------------------------------------------
--
--   NXP B.V. confidential and proprietary.
--   COPYRIGHT (c) NXP B.V. 2007
--
--   All rights are reserved. Reproduction in whole or in part is
--   prohibited without the written consent of the copywright owner
--
--   CoReUse 4.4 information header
--
--  ----------------------------------------------------------------------------
--                     Design Information
--  ----------------------------------------------------------------------------
--
--               File: usb_sieint.m.vhdl
--
--             Author: Bart Vertenten
--
--       Organisation: Corporate I&T / IP & Architecture
--
--              $Date: Sun Apr 23 19:20:43 2017 $
--
--            Project: IP_3511 - Low gate count USB peripheral IP 
--
--        Description: 
--
--          $Revision: 1.4 $
--
--  ----------------------------------------------------------------------------
--                     Revision History
--  ----------------------------------------------------------------------------
--
--   $Log: usb_sieint.m.vhdl.rca $
--   
--    Revision: 1.4 Sun Apr 23 19:20:43 2017 cnh20323
--    copy mco/ip_xxx_3516_hs_mem_sms/3.0.0 to projects/next0
--    
--   
--    Revision: 1.11 Wed Jan  4 13:23:15 2012 beq03099
--    BufferSize must be set to 0 when epinfo_active is 0b and epinfo_iso is 1b
--   
--    Revision: 1.10 Wed Jun 15 15:36:38 2011 beq03099
--    fixed possible synchronization problem with sentNAK signal
--   
--    Revision: 1.9 Fri Apr 29 12:30:40 2011 beq03099
--    added buffer underrun indication
--   
--    Revision: 1.8 Mon Mar  7 20:18:49 2011 beq03099
--    added endpoint check for hub and embedded device
--   
--    Revision: 1.7 Thu Feb 24 09:33:22 2011 beq03099
--    removed usb_cfg package
--   
--    Revision: 1.6 Fri Feb 18 11:01:29 2011 beq03099
--    fixed bit width problem
--   
--    Revision: 1.5 Wed Feb  9 13:47:46 2011 beq03099
--    made size of rxnbytes and txnbytes configurable to support hs device
--   
--    Revision: 1.4 Thu Jul 22 17:47:05 2010 beq03099
--    modifications required for new constant C_DALB
--   
--    Revision: 1.3 Thu Jun 17 08:52:29 2010 beq03099
--    fixed spyglass warning on sieint_errortype
--   
--    Revision: 1.2 Tue Jun  8 10:08:56 2010 bve
--    Fixed conformal warnings
--   
--    Revision: 1.1 Fri May 21 08:55:00 2010 aes
--    First check in.
--   
--    Revision: 1.2 Thu Apr  1 11:24:31 2010 bve
--    .\  fixed typo
--   
--    Revision: 1.1 Thu Apr  1 09:49:54 2010 bve
--    Initial version
--   
--   
--   
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;
use usb_lib.usb_subcmp_pkg.all;
use usb_lib.usb_configuration_subcmp_pkg.all;

entity  usb_sieint is
  generic(C_NBDEV          : integer := 1;
          TXNBYTES_BITS    : integer := 10;
          RXNBYTES_BITS    : integer := 11;
          C_NBPHYSEP       : integer := 14);
  port  (
         -------- To SIE -----------------------------
         SIE_StartEndpSearch:   in  boolean;        -- Start Address Lookup
         MM_EndpSearchReady:    out boolean;        -- Search Ready
         MM_EndpSearchSelected: out boolean;        -- Device Selected
         SIE_RxEOP:             in  boolean;        -- Received End of Packet
         SIE_RxPid:             in  T_Pid_enum;     -- Pid of Rx packet
         SIE_RxSubPid:          in  T_SubPid_enum;  -- SubPid of LPM Rx packet
         SIE_RxPidRdy:          in  boolean;        -- Pid ready
         SIE_RxData:            in  S_UsbWord_bits; -- Received Data
         SIE_RxDataRdy:         in  boolean;        -- Received Data Valid
         SIE_RxErrorType:       in  T_PACKET_ERROR_enum; -- Error type
         SIE_LPM_HIRDRdy:       in boolean;         -- Received HIRD value
         SIE_LPM_RWRdy:         in boolean;         -- Received RemoteWakeup value      
     
         SIE_RxError:           in  boolean;        -- Error ?
         SIE_SOFByte1:          in  boolean; --
                                    --Received Data is 1st byte of frame number
         SIE_SOFByte2:          in  boolean; --
                                    --Received Data is 2nd byte of frame number
         MM_TxData:             out S_UsbWord_bits; -- Data to Transmit
         MM_TxDataRdy:          out boolean;        -- Data to Transmit valid
         MM_TxData1Pid:         out boolean;        -- Send Data1 Packet 
         SIE_TxDataAck:         in  boolean;        -- Data to transmit fetched
         MM_Accepted:           out boolean;        -- Accepted
         MM_Stalled:            out boolean;        -- Stalled
         MM_LPMSupported:       out boolean;        -- LPMSupported response
         MM_LPMNYET:            out boolean;        -- LPMNYET response
         MM_all_bytes_sent:     out boolean;
     
         MM_ISO:                out boolean;        -- Isochronous transfer
         MM_Resume:             out boolean;        -- Generate remote wakeup
         LPM_MM_Resume:         out boolean;        -- Generate LPM remote wakeup
         MM_NeedClock:          out boolean;        -- Clock is needed 

         -- From EP Handler
         LPM_RW:                out boolean;
         LPM_NYET:              in  boolean;        -- NYET response
         LPM_HIRD_HW:           out four_bits;      -- HIRD value from Host
         LPM_HIRD_Rdy:          out boolean;        -- HIRD Ready
         LPM_LINK_STATE_EN:     out boolean;        -- LPM Extended token Link state enable

         ----- To/From ahb synchronizer - fs_dma ----------------
         sieint_epinfo_req:     out std_logic;                   
         sieint_epinfo_epnr:    out std_logic_vector(3 downto 0);
         sieint_epinfo_epdir:   out std_logic;
         sieint_epinfo_setup:   out std_logic;
         sieint_usbaddres:      out std_logic_vector(6 downto 0);
         sieint_dev_selected:   out integer range 0 to C_NBDEV - 1;
         epinfo_valid:          in  std_logic;                   
         
         epinfo_active:         in  std_logic;
         epinfo_disabled:       in  std_logic;
         epinfo_toggle:         in  std_logic;
         epinfo_stall:          in  std_logic;
         epinfo_iso:            in  std_logic;
         epinfo_ratefeedbackmode:in std_logic;
         epinfo_nbytes:         in  std_logic_vector(TXNBYTES_BITS-1 downto 0);
         
         sieint_txdatafetched:  out std_logic;                   
         epinfo_txdata:         in  std_logic_vector(7 downto 0);
         epinfo_txdata_valid:   in  std_logic;                   
         
         sieint_rx_nbytes:      out std_logic_vector(RXNBYTES_BITS-1 downto 0);
         sieint_rxdata:         out std_logic_vector(7 downto 0);
         sieint_rxdatavalid:    out std_logic;                   
         
         sieint_endtransfer:    out std_logic;
         sieint_success:        out std_logic; 
         sieint_error:          out std_logic;
         sieint_errortype:      out std_logic_vector(3 downto 0);
         sieint_sentNAK:        out std_logic;

         ------ To/From ahb register module - pseudo-static signals
         usbreg_pll_on:         in  std_logic;
         usbreg_deviceenabled:  in  std_logic_vector(C_NBDEV-1 downto 0);
         usbreg_remotewakeup:   in  std_logic;
         usbreg_lpm_sup:        in  std_logic;
         usbreg_lpmremotewakeup:in  std_logic;
         usbreg_frame_number:   out std_logic_vector(10 downto 0);
         usbreg_usbaddress:     in  std_logic_vector(C_NBDEV*7-1 downto 0);
         usbreg_usbaddress_tmp: in  std_logic_vector(C_NBDEV*7-1 downto 0);

         ---------- LED control -------------
         SH_Succes:            out boolean;          -- Transfer was succesfull
         SH_Configured:        out boolean;          -- Device is configured

         ------ System ---------------------
         FsClk:                 in one_bit;          -- Recovered Clock
         Reset_N:               in one_bit           -- Global Reset
         
        );
end usb_sieint;

architecture RTL of usb_sieint is

  signal DataPid: integer range 0 to 1;
  signal IgnoreData:boolean;
  signal StopReceiving: boolean;

  signal EndOfTransfer: boolean;
  signal SetupPacket: boolean;

  signal EndpNr                : integer range 0 to 15;
  signal Direction             : boolean;
  signal DataSentReceived      : boolean;
  signal SOFByte1              : byte;
  
  signal hub_selected : std_logic;
  signal emb_dev_selected : std_logic;

begin

MM_TxData1Pid   <= (DataPid = 1);
SH_Configured   <= (usbreg_deviceenabled(0) = '1'); -- goes to upstreamled module - was deviceconfigured before

MM_NeedClock    <= (usbreg_pll_on = '1');        
MM_Resume       <= (usbreg_remotewakeup = '1');        -- Does this need to go through synchronizer ?
LPM_MM_Resume   <= (usbreg_lpmremotewakeup = '1');     -- Does this need to go through synchronizer ?

MM_TxData       <= unsigned(epinfo_txdata);
MM_TxDataRdy    <= (epinfo_txdata_valid = '1');
sieint_txdatafetched <= '1' when SIE_TxDataAck else '0';

MM_LPMSupported <= (usbreg_lpm_sup = '1');
MM_LPMNYET      <= LPM_NYET ;


MAIN: process (FsClk, Reset_N) 

  type T_SH_State_enum is ( 
                          DEVADDR_SEARCH,
                          WAIT_FOR_ENDPOINT,
                          WAIT_FOR_ENDOFTOKEN,
                          LPM_HIRD,
                          LPM_REMOTEWAKEUP,
                          LPM_ENDOFTOKEN,
                          WAIT_FOR_DATA,
                          RECEIVE_OUT_PACKET,
                          SEND_IN_PACKET
                                 );
  variable SH_State: T_SH_State_enum;                          

  variable DevAddrEnabled        : boolean;
  variable N_Data                : integer range 0 to MAX_BUFFER_SIZE+3;
  variable N_Data_bits           : eleven_bits;
  variable BufferSize            : integer range 0 to MAX_BUFFER_SIZE;
  variable OverRunSize           : integer range 0 to MAX_BUFFER_SIZE+2;
  variable TokenReceived         : boolean;
  variable EndpSearchReady       : boolean;
  variable RxData1Pid            : boolean;
  variable var_address1          : unsigned(6 downto 0);
  variable var_address2          : unsigned(6 downto 0);


  -- DOC_BEGIN: Procedure SetEndpointSelected
  -- SetEndpointSelected sets all necessary signals to indicate to the
  -- SIE that the addressed endpoint is part of the device.
  procedure SetEndpointSelected is
  begin
    EndpSearchReady := TRUE;
    MM_EndpSearchSelected <= TRUE;
  end;
  -- DOC_END

  
  -- DOC_BEGIN: Procedure SetNoEndpointSelected
  -- SetNoEndpointSelected sets all necessary signals to indicate to the
  -- SIE that the addressed endpoint is not part of the device.
  procedure SetNoEndpointSelected is
  begin
    EndpSearchReady := TRUE;
    MM_EndpSearchSelected <= FALSE;
  end;
  -- DOC_END

  -- DOC_BEGIN: Procedure SetError
  -- SetError generates an error of the specified type.
  procedure SetError(SetErrorType: T_PACKET_ERROR_enum) is
  begin
    sieint_error         <= '1';
    case SetErrorType is 
      when ERROR_NO_ERROR         => sieint_errortype <= "0000";
      when ERROR_PID_ENCODING     => sieint_errortype <= "0001";
      when ERROR_PID_UNKNOWN      => sieint_errortype <= "0010";
      when ERROR_PACKET_UNEXPECTED=> sieint_errortype <= "0011";
      when ERROR_TOKEN_CRC        => sieint_errortype <= "0100";
      when ERROR_DATA_CRC         => sieint_errortype <= "0101";
      when ERROR_TIMEOUT          => sieint_errortype <= "0110";
      when ERROR_BABBLE           => sieint_errortype <= "0111";
      when ERROR_TR_EOP           => sieint_errortype <= "1000";
      when ERROR_SENT_RECEIVED_NAK=> sieint_errortype <= "1001";
      when ERROR_SENT_STALL       => sieint_errortype <= "1010";
      when ERROR_OVERRUN          => sieint_errortype <= "1011";
      when ERROR_SENT_EMPTYPACK   => sieint_errortype <= "1100";
      when ERROR_BITSTUFF_ERROR   => sieint_errortype <= "1101";
      when ERROR_SYNC_ERROR       => sieint_errortype <= "1110";
      when others --ERROR_DATA_IGNORED_WRONG_DATA01
                                  => sieint_errortype <= "1111";
    end case;
--    if SH_State = DEVADDR_SEARCH then
--      sieint_endtransfer <= '0';
--    else
      sieint_endtransfer <= '1';
--    end if;
    sieint_success <= '0';
    if SetErrorType = ERROR_SENT_RECEIVED_NAK then
      sieint_sentNAK <= '1';
    end if;
    SH_State := DEVADDR_SEARCH;
  end;
  -- DOC_END

  procedure SetSuccessAtEOP is
  begin
    EndOfTransfer  <= TRUE;
    sieint_success <= '1';
    SH_State       := DEVADDR_SEARCH;
    SH_Succes      <= TRUE;
  end;

  procedure SetSuccess is
  begin
    sieint_endtransfer <= '1';
    EndOfTransfer <= FALSE;
    sieint_success <= '1';
    SH_State := DEVADDR_SEARCH;
    SH_Succes <= TRUE;
  end;
begin 

  if (Reset_N = ACTIVE_LOW) then

    SH_State                       := DEVADDR_SEARCH;
    SOFByte1                       <= (others => '0');
    MM_EndpSearchReady             <= FALSE;
    EndpSearchReady                := FALSE;
    MM_EndpSearchSelected          <= FALSE;
    EndpNr                         <= 0;
    MM_Stalled                     <= FALSE;
    MM_Accepted                    <= FALSE;
    DataPid                        <= 0;
    IgnoreData                     <= FALSE;
    N_Data                         := 0;
    MM_ISO                         <= FALSE;
    Direction                      <= FALSE;
    TokenReceived                  := FALSE;
    DataSentReceived               <= FALSE;
    SH_Succes                      <= FALSE;
    BufferSize                     := 0;
    RxData1Pid                     := FALSE;
    OverRunSize                    := 0;
    SetupPacket                    <= FALSE;
    EndOfTransfer                  <= FALSE;
    DevAddrEnabled                 := FALSE;
    LPM_HIRD_HW                    <= (others => '0');
    LPM_HIRD_Rdy                   <= FALSE;
    StopReceiving                  <= FALSE;
    LPM_LINK_STATE_EN              <= FALSE;
    LPM_RW                         <= FALSE;
    sieint_epinfo_req              <= '0';
    sieint_endtransfer             <= '0';
    sieint_sentNAK                 <= '0';
    sieint_error                   <= '0';
    sieint_errortype               <= (others => '0');
    sieint_success                 <= '0';
    usbreg_frame_number            <= (others => '0');
    sieint_usbaddres               <= (others => '0');
    sieint_dev_selected            <= 0;
    MM_all_bytes_sent              <= FALSE;

  elsif (FsClk'event and FsClk = '1') then

    --sieint_sentNAK                 <= '0';
    SH_Succes                      <= FALSE;
    LPM_HIRD_Rdy                   <= FALSE;

    -- DOC_BEGIN: Error Handling
    -- When there is no error generated in the SIEINTERFACE module, the error
    -- code coming from the SIE is copied.
    
    if (SIE_RxError) then
      if not(epinfo_ratefeedbackmode = '1' and SIE_RxErrorType = ERROR_PACKET_UNEXPECTED) then
        SetError(SIE_RxErrorType);
      end if;
    end if;
    -- DOC_END

    -- DOC_BEGIN: Main State Machine
    case SH_State is 

      -- In this state, the SIEINTERFACE waits to be triggered to do
      -- an address lookup when a token comes in.
      --
      when DEVADDR_SEARCH =>
        MM_EndpSearchReady    <= TRUE ;
        TokenReceived         := FALSE;
        DataSentReceived      <= FALSE;
        StopReceiving         <= TRUE ;
        sieint_epinfo_req     <= '0';
          -- DOC_END
          
    
        -------------------------------------------------------------------
        --                        Receiving a SOF                        --
        -------------------------------------------------------------------
    
        -- DOC_BEGIN
            -- When a Start of Frame (SOF) comes in, the frame number
            -- is updated.
        if SIE_SOFByte1 then
          SOFByte1 <= SIE_RxData;
        elsif SIE_SOFByte2 and (not SIE_RxError) then
          usbreg_frame_number(10 downto 8) <= std_logic_vector(SIE_RxData(2 downto 0));
          usbreg_frame_number( 7 downto 0) <= std_logic_vector(SOFByte1);
        end if;
            -- DOC_END
    
    
        -------------------------------------------------------------------
        --                  Receiving an IN/OUT/SETUP Token              --
        -------------------------------------------------------------------
    
    
        -- DOC_BEGIN
            -- When the SIEINTERFACE is triggered on the arrival of a token, 
            -- all protocol signals to the SIE are initialized and a device
            -- address lookup is done. If the address in the token is the address
            -- of an enabled device, the state machine jumps to the 
            -- WAIT_FOR_ENDPOINT state, where it waits for the endpoint number
            -- to come in. Otherwise, it stays in the DEV_ADDR_SEARCH and waits
            -- for the next token.
    
        if (SIE_StartEndpSearch) then
    
          MM_EndpSearchReady    <= FALSE;
          EndpSearchReady       := FALSE;
          MM_EndpSearchSelected <= FALSE;
          MM_Accepted           <= FALSE;
          MM_Stalled            <= FALSE;
          sieint_sentNAK        <= '0';
          sieint_endtransfer    <= '0';
          sieint_success        <= '0'; 
          sieint_error          <= '0';
    
          -- loop through device address table (content search);
          DevAddrEnabled := FALSE;
          for i in 0 to C_NBDEV-1 loop
            for j in 0 to 6 loop
              var_address1(j) := usbreg_usbaddress(i*7+j);
              var_address2(j) := usbreg_usbaddress_tmp(i*7+j);
            end loop;
            if (var_address1 = SIE_RxData(6 downto 0)  or 
                var_address2 = SIE_RxData(6 downto 0)) and
                usbreg_deviceenabled(i) = '1'           then
              sieint_usbaddres    <= std_logic_vector(SIE_RxData(6 downto 0));
              DevAddrEnabled      := TRUE;
              sieint_dev_selected <= i;
            end if;
          end loop;
          
          -- if device enabled, proceed to check endpoint
          if DevAddrEnabled then
            SH_State := WAIT_FOR_ENDPOINT;
          else 
            SetNoEndpointSelected;
          end if;
    
        end if;


      -- When the endpoint number arrives, a check is done whether
      -- the endpoint exists, is enabled and can handle the current
      -- data direction. If there is a match, more endpoint data are
      -- retrieved in the WAIT_FOR_ENDOFTOKEN state. Otherwise the SIEINTERFACE
      -- waits for the next token.
      when WAIT_FOR_ENDPOINT =>
        -- wait until endpoint number is available
        if SIE_RxDataRdy then
          EndpNr      <= to_integer(SIE_RxData);
          Direction   <= (SIE_RxPid = PID_IN);   -- encode as std_logic !
          SetupPacket <= (SIE_RxPid = PID_SETUP);
          -- pid must have right direction and EP must be enabled
          if (SIE_RxPid = PID_LPM) then 
            SH_State := WAIT_FOR_ENDOFTOKEN;
          elsif to_integer(SIE_RxData) <= C_NBPHYSEP/2 then
            sieint_epinfo_req <= '1';
            SH_State:=WAIT_FOR_ENDOFTOKEN;
          else 
            SetNoEndpointSelected;
          end if;
        end if;
        
      -- In this state, the SIEINTERFACE waits for the end of the token
      -- packet. At that moment, all flags for the SIE are set to 
      -- generate the right answer.

-------------------------------------------------------------------------------       
-- LPM_CHANGE
-- In WAIT_FOR_ENDOFTOKEN state if PID received was for the LPM token then
-- state machine transitions to the LPM_HIRD state. The WAIT_FOR_ENDOFTOKEN  
-- state handles the End of token for the standard packet recieved.
-------------------------------------------------------------------------------

      when WAIT_FOR_ENDOFTOKEN =>
        DataPid <= to_integer(epinfo_toggle);    
        N_Data  :=0;
        if SIE_RxEOP and (SIE_RxPid = PID_LPM) then
          StopReceiving <= FALSE;
          SetEndpointSelected;
          SH_State := LPM_HIRD; 
--        elsif SIE_RxEOP and (epinfo_disabled = '1' or epinfo_valid = '0') then
        elsif epinfo_valid = '1' and epinfo_disabled = '1' then
          SetNoEndpointSelected;
--BVE : Added SetError to make sure that an sieint_endtransfer is signaled to the dma block
          SetError(ERROR_PACKET_UNEXPECTED);
          SH_State := DEVADDR_SEARCH;
--        elsif SIE_RxEOP then  
        elsif epinfo_valid = '1' then  
          StopReceiving <= FALSE;
          SetEndpointSelected;
          MM_ISO <= FALSE;
          if epinfo_iso = '1' then
            MM_ISO <= TRUE;
            DataPid <= 0; -- always send DATA0
          end if;
          if SIE_RxPid = PID_SETUP then
            -- always accept a setup packet
            DataPid <= 0; -- Always DATA0 PID
            MM_Stalled <= FALSE;
            SH_State := WAIT_FOR_DATA;
          elsif SIE_RxPid = PID_OUT then
-- BVE : Remove the check on Endpoint number 0
--       It must be possible to send a STALL on an OUT to endpoint 0
--            if (EndpNr = 0) then
--              SH_State := WAIT_FOR_DATA;
--            else
              MM_Stalled <= (epinfo_stall = '1');
              -- Decide how to handle OUT token
              if epinfo_stall = '1' then
                -- Endpoint Stalled -> Send STALL
                SetError(ERROR_SENT_STALL);
              else
                -- Otherwise Receive Data
                SH_State := WAIT_FOR_DATA;
              end if;
--            end if;
          else  -- PID_IN
            MM_Stalled <= (epinfo_stall = '1');
            -- Decide how to handle IN token
            if epinfo_stall = '1' then
              -- Endpoint Stalled -> send stall
              SetError(ERROR_SENT_STALL);
            elsif epinfo_active = '0' and epinfo_iso = '1' then
              -- Otherwise No data and ISO -> send empty packet
              MM_Accepted <= TRUE;
              SetError(ERROR_SENT_EMPTYPACK);
            elsif epinfo_active = '0' then
              -- Otherwise No data  -> send nak
              SetError(ERROR_SENT_RECEIVED_NAK);
            else
              -- Otherwise send data
              MM_Accepted <= TRUE;
              SH_State := SEND_IN_PACKET;
              if epinfo_ratefeedbackmode = '1' then
                MM_ISO <= TRUE;
              end if;  
            end if;
          end if;
        end if;

-------------------------------------------------------------------------------       
-- LPM_CHANGE
-- SIE receives the second part of the LPM token and asserts SIE_LPM_HIRDRdy 
-- to indicate that HIRD field has been received. LPM_HIRD state stores the 
-- value of HIRD conveys it to system register and TIMER_SF module.
-------------------------------------------------------------------------------

       when LPM_HIRD =>
         if (SIE_RxSubPid = LPM_SubPID) AND SIE_LPM_HIRDRdy then
           LPM_HIRD_HW       <= SIE_RxData(7 downto 4);
           LPM_HIRD_Rdy      <= TRUE;
           LPM_LINK_STATE_EN <= FALSE;
           if (SIE_RxData(3 downto 0) = "0001") then
             LPM_LINK_STATE_EN <= TRUE;
           end if;
           SH_State := LPM_REMOTEWAKEUP;
         end if;
         
-------------------------------------------------------------------------------       
-- LPM_CHANGE 
-- When SIE asserts SIE_LPM_RWRdy it indicates that LPM attribute field was 
-- received. In this LPM_REMOTEWAKEUP state a remotewakeup bit of attribute
-- field is stored. The remote wakeup information is sent to Device Handler
-- Device Handler stores the remote wakeup bit in device status register.
-------------------------------------------------------------------------------
      when LPM_REMOTEWAKEUP =>
        LPM_RW <= FALSE;                         
        if (SIE_RxSubPid = LPM_SubPID) AND SIE_LPM_RWRdy then
          if (SIE_RxData(0) = '1') then 
            LPM_RW  <= TRUE;                     
          end if;
          SH_State := LPM_ENDOFTOKEN;
        end if;
      
-------------------------------------------------------------------------------       
-- LPM_CHANGE 
-- LPM_ENDOFTOKEN state handles the End of LPM extended token.
-------------------------------------------------------------------------------
      when LPM_ENDOFTOKEN =>
        if SIE_RxEOP then
          StopReceiving <= FALSE;  
          SH_State := DEVADDR_SEARCH;
        end if;

      -- In this state, the SIEINTERFACE waits for the data packet to 
      -- arrive. When the PID comes in, a decision is taken whether
      -- the packet must be accepted or ignored, depending on the
      -- DATA0/1 sequence.
      when WAIT_FOR_DATA =>
        if SIE_RxPidRdy then   
          RxData1Pid := (SIE_RxPid = PID_DATA1);
          IgnoreData <= ((DataPid=1) and (not RxData1Pid)) or
                            ((DataPid=0) and RxData1Pid);
          if RxData1Pid then
            DataPid <= 1;
          else
            DataPid <= 0;
          end if;
          if epinfo_iso = '1' then
            IgnoreData <= FALSE;
          end if;
          N_Data:=0; 
          SH_State := RECEIVE_OUT_PACKET;
        end if;
      
      -- In the RECEIVE_OUT_PACKET state, the data part of the data packet
      -- is received, and all incoming data are stored into the endpoint's
      -- buffer. An error is generated on buffer overflow.
      -- At the end of the packet, the endpoint's setup information is
      -- updated.
      when RECEIVE_OUT_PACKET =>
-- Bulk endpoint modification
--        BufferSize  := to_integer(unsigned(epinfo_nbytes));
        if epinfo_active = '1' then
          if to_integer(unsigned(epinfo_nbytes)) > MAX_BUFFER_SIZE then
            BufferSize := MAX_BUFFER_SIZE;
          else
            BufferSize := to_integer(unsigned(epinfo_nbytes));
          end if;
        else
          BufferSize  := 64; --MaxPacketSize for Bulk, Interrupt and Control
        end if;
---------------------------
        OverRunSize := BufferSize +2;

        if SIE_RxDataRdy and not IgnoreData then
          if N_Data < OverRunSize then
            N_Data := N_Data +1;
          else
            SetError(ERROR_OVERRUN);
            MM_ISO <= TRUE; -- no ack
          end if;
          if N_Data >= BufferSize then
            StopReceiving <= TRUE;
          end if;
        elsif DataSentReceived then
          MM_Accepted <= (epinfo_active = '1') or SetupPacket or IgnoreData;
          if not(epinfo_active = '1' or epinfo_stall = '1' or SetupPacket or IgnoreData) then
            SetError(ERROR_SENT_RECEIVED_NAK);
          elsif IgnoreData then
            SetError(ERROR_DATA_IGNORED_WRONG_DATA01);
          else
            N_Data := N_Data -2;
            SetSuccess;
          end if;
        end if;

      -- In this state, the SIEINTERFACE sends a data packet to the host.
      -- First the number of data is read from the RAM. After that,
      -- that amount of data is read from the endpoint's buffer and
      -- is sent to the SIE.
      -- At the end, the endpoint's setup information is updated.
      when SEND_IN_PACKET =>
        if epinfo_disabled = '1' then
          SH_State := DEVADDR_SEARCH;
        else   
          if SIE_TxDataAck then        -- check where the NBytes value is taken !!!
            N_Data := N_Data+1;
          end if;
          if DataSentReceived then
            if epinfo_iso = '1' or epinfo_ratefeedbackmode = '1' then
              SetSuccess;
            end if;
          end if;
          if SIE_RxPidRdy then
            if SIE_RxPid = PID_ACK then
              SetSuccessAtEOP;
            else 
              SetError(ERROR_SENT_RECEIVED_NAK);
            end if;
          end if;
        end if;
    end case; -- SH_STATE;
    -- DOC_END

    -------------------------------------------------------------------
    --                        Error Handling                         --
    -------------------------------------------------------------------

    --  Check for DataSentReceived and TokenReceived after errors
    --  are handled, to be sure that no errors are missed.

    if SIE_RxEOP and TokenReceived then
      DataSentReceived <= TRUE;
    end if;

    if SIE_RxEOP then
      TokenReceived := TRUE;
    end if;


    if TokenReceived then
      MM_EndpSearchReady <= EndpSearchReady;
    end if;

    if EndOfTransfer and SIE_RxEOP then
      sieint_endtransfer <= '1';
      EndOfTransfer <= FALSE;
    end if;

    if epinfo_active = '1' then
      if to_integer(unsigned(epinfo_nbytes)) > MAX_BUFFER_SIZE then
            BufferSize := MAX_BUFFER_SIZE;
      else
            BufferSize := to_integer(unsigned(epinfo_nbytes));
      end if;
    elsif epinfo_iso = '1' then
      BufferSize  := 0;
    else
      BufferSize  := 64; --MaxPacketSize for Bulk, Interrupt and Control
    end if;
    if N_Data = BufferSize then
      MM_all_bytes_sent <= TRUE;
    else
      MM_all_bytes_sent <= FALSE;
    end if;
  end if;

  sieint_rx_nbytes <= std_logic_vector(to_unsigned(N_Data,RXNBYTES_BITS));

end process MAIN;

sieint_rxdata       <= std_logic_vector(SIE_RxData);
sieint_rxdatavalid  <= '1' when SIE_RxDataRdy and not StopReceiving and not IgnoreData else '0';
sieint_epinfo_epnr  <= std_logic_vector(to_unsigned(EndpNr,4));
sieint_epinfo_epdir <= '1' when Direction   else '0'; -- '1' : IN direction / '0' : OUT direction
sieint_epinfo_setup <= '1' when SetupPacket else '0';         

end RTL;
