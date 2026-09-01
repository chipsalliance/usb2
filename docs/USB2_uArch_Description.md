## Architecture Overview

The IP implements a USB 2.0 compound device composed of:

- one embedded two-port USB Hub;
- two software-controlled downstream USB devices, DEV0 and DEV1;
- one shared USB Protocol and Interface Engine;
- one shared endpoint data manager;
- independent control interfaces and Endpoint RAMs for DEV0 and DEV1.

The embedded Hub is assigned function index `0`, DEV0 is assigned index `1`,
and DEV1 is assigned index `2`.

The shared USB Protocol and Interface Engine receives the enable state,
current address, and temporary address of all three functions. For each USB
transaction, the protocol engine performs function address matching and
generates the selected-function index.

The selected-function index controls:

- Hub versus software-device access selection;
- DEV0 versus DEV1 Endpoint RAM selection;
- endpoint-context selection;
- SETUP-event routing;
- DMA endpoint-state update routing;
- grant and read-data response selection.

The embedded Hub uses a register-based endpoint implementation. Its EP0 and
EP1 IN runtime contexts are maintained by dedicated hardware, while
descriptors and the SETUP request decode table are stored in an external Hub
Descriptor RAM.

DEV0 and DEV1 use independent Endpoint RAMs containing their Endpoint Lists,
endpoint contexts, and TX/RX payload buffers. Each RAM can be accessed both
by the internal USB data path and by an external AHB master.

The USB protocol logic operates in the `pie_clk` domain. Endpoint processing,
register interfaces, Hub control, DMA operation, and AHB access operate in
the `hclk` domain. A dedicated clock-domain bridge transfers control, status,
event, context, and payload information between the two domains.

## Detailed Architecture

The following diagram provides a detailed view of the USB compound device architecture, including its functional partitioning, internal connectivity, and main interfaces.

![USB Two-Port Compound Device Block Diagram](USB_uArch_Detailed_Block_Diagram.svg)

The following sections describe the role, connectivity, and operational behavior of each block shown in the diagram.

---

## Main RTL Blocks

### USB 2.0 UTMI or ULPI PHY

The external PHY implements the electrical and low-level signaling interface
to the USB bus.

The IP supports UTMI and ULPI interface alternatives. The selected PHY clock
is used to generate `pie_clk`, while the active PHY interface exchanges
packet data, line state, transmit control, receive status, and low-power
signaling with the shared USB Protocol and Interface Engine.

The PHY boundary is external to the compound-device IP.

---

### `usb_pie_1` - USB Protocol and Interface Engine

**Entity:** `usb_pie`  
**Source:** `RTL/usb_pie.m.vhdl`  
**Clock domain:** `pie_clk`

`usb_pie_1` is the shared USB protocol engine used by the embedded Hub, DEV0,
and DEV1.

The PIE performs:

- UTMI and ULPI interface control;
- USB packet transmission and reception;
- token and packet-type decoding;
- USB address matching;
- Hub, DEV0, or DEV1 function selection;
- endpoint number and direction decoding;
- endpoint-context request generation;
- TX and RX payload exchange;
- USB handshake generation;
- transfer completion and result reporting;
- USB reset, suspend, resume, and LPM handling;
- Full-Speed and High-Speed protocol handling;
- USB frame and microframe timing.

The PIE receives an aggregated function-selection context containing the
effective enable, current address, and temporary address of each USB
function. When a token is accepted, the PIE generates `pie_dev_selected` to
identify the target function.

The PIE does not know whether the selected endpoint context is implemented
in registers or RAM. It uses a common endpoint-information interface and
relies on the downstream routing and endpoint data path to obtain context and
payload information.

For a received SETUP transaction, the PIE:

1. selects the addressed USB function;
2. requests the associated EP0 context;
3. identifies the transaction as SETUP;
4. transfers the eight-byte SETUP payload to the endpoint data manager;
5. generates a SETUP-received event once the packet has been accepted.

---

### `usb_synchronizer_1` - USB Clock-Domain Bridge

**Entity:** `usb_synchronizer`  
**Source:** `RTL/usb_synchronizer.m.vhdl`  
**Clock domains:** `pie_clk` and `hclk`

`usb_synchronizer_1` is the central clock-domain bridge between the USB
protocol domain and the system-side endpoint-processing domain.

The bridge transfers:

- endpoint-context requests;
- endpoint number, direction, and SETUP indication;
- selected-function index;
- SETUP-received events;
- endpoint context and runtime state;
- TX and RX payload data;
- transfer-completion and result events;
- bus reset, suspend, LPM, speed, and frame information;
- USB/PHY control and PHY register-access information.

The implementation uses synchronization methods appropriate to the type of
information being transferred, including status synchronization, event
transfer, and event-qualified data transfer.

Architecturally, the block establishes the boundary between:

- USB packet and link processing in the `pie_clk` domain;
- endpoint context, payload, register, and Hub processing in the `hclk`
  domain.

---

### `usb_dma_1` - Endpoint Data Manager

**Entity:** `usb_dma`  
**Source:** `RTL/usb_dma.m.vhdl`  
**Clock domain:** `hclk`

`usb_dma_1` is the shared endpoint context and payload-transfer engine for
the Hub, DEV0, and DEV1.

For each request generated by the PIE, the endpoint data manager first
retrieves the context of the selected endpoint. The returned context allows
the PIE to determine whether the endpoint is active, disabled, stalled, or
ready to transfer data, as well as the current toggle, available byte count,
maximum packet information, and endpoint type.

After the context lookup, the endpoint data manager performs the required
payload operation:

- TX payload fetch for an IN transaction;
- RX payload store for an OUT transaction;
- eight-byte SETUP payload transfer for a SETUP transaction;
- endpoint runtime-state update after transfer completion.

For a SETUP transaction, the endpoint data manager applies special behavior,
including:

- forcing an eight-byte transfer size;
- selecting the SETUP buffer entry;
- treating the transfer differently from a normal EP0 OUT transaction.

For DEV0 and DEV1, the endpoint data manager accesses the selected Endpoint
RAM. For the Hub, the endpoint data manager accesses dedicated hardware
resources through the Hub function path.

The endpoint data manager also updates endpoint state after a transfer,
including active state, byte count, toggle-related state, interrupt state,
buffer selection, and skip state.

---

### `usb_fs_mux_1` - USB DMA Path Mux

**Entity:** `usb_fs_mux`  
**Source:** `RTL/usb_fs_mux.m.vhdl`  
**Implementation:** combinational

`usb_fs_mux_1` routes each shared endpoint access generated by `usb_dma_1`
toward one of two mutually exclusive paths:

- the embedded Hub function path;
- the DEV0/DEV1 Endpoint RAM path.

The path is selected using `dma_ahb_selected`, which is derived from the
function selected by the PIE:

- Hub selected: route the access to `upd_dma_*`;
- DEV0 or DEV1 selected: route the access to `ahb_dma_*`.

The block distributes address, write control, and write data to both paths,
but asserts the request only on the selected path. Grant and read data from
the selected path are multiplexed back to `usb_dma_1`.

The block contains no registers, FSM, or arbitration policy.

---

### Selected-Function Context, Event, and RAM Routing

**Implementation:** top-level combinational and sequential logic  
**Clock domain:** primarily `hclk`

This top-level logic uses `sync_pie_dev_selected` to select and route the
state associated with the function currently being serviced.

The function-index mapping is:

```text
0: Embedded Hub
1: DEV0
2: DEV1
```

The logic selects the function context presented to `usb_dma_1`, including:

- Endpoint List base;
- data-buffer base;
- endpoint skip state;
- current buffer selection;
- endpoint toggle state;
- software SETUP-pending state.

For DEV0 and DEV1, these values are selected from the corresponding
`usb_reg_if` instance.

For the Hub, the logic supplies predefined address-mapping values that allow
the endpoint data manager to access the dedicated hardware regions:

```text
00: Hub EP0 data and response path
01: Hub Status Change EP1 IN payload
10: Unimplemented
11: Hub endpoint context
```

The same selected-function index also controls:

- Hub versus software-device DMA-path selection;
- DEV0 versus DEV1 Endpoint RAM selection;
- SETUP-event destination;
- DMA endpoint-state update destination;
- grant and read-data response selection.

This logic provides the central connection between the function selected by
the PIE and the physical register or memory resources that implement the
selected endpoint.

---

## Embedded Hub Subsystem

### `hub_ep0_handler_1` - Hub EP0 Request Handler

**Entity:** `usb_ep0_handler`  
**Source:** `RTL/usb_ep0_handler.m.vhdl`  
**Clock domain:** `hclk`

`hub_ep0_handler_1` implements the control-endpoint processing for the
embedded Hub function. It does not process EP0 transactions for DEV0 or DEV1.

The eight-byte SETUP packet received through the endpoint data manager is
stored internally in `setup_bytes[63:0]`.

After the Hub SETUP-decode trigger is received, the handler:

1. reads the Hub device-link entry from the Hub Descriptor RAM;
2. locates the associated SETUP decode table;
3. compares the stored SETUP packet against table patterns and masks;
4. obtains the internal request code and response-buffer selection;
5. prepares the context for the subsequent EP0 DATA or STATUS stage.

The handler directly processes supported USB standard requests, including:

- `SET_ADDRESS`;
- `SET_CONFIGURATION`;
- `GET_CONFIGURATION`;
- `GET_INTERFACE`;
- Device, Interface, and Endpoint `GET_STATUS`;
- Device and Endpoint `SET_FEATURE`;
- Device and Endpoint `CLEAR_FEATURE`.

Short standard-request responses are generated internally from current
device or endpoint state and protocol-defined constant fields. The generated
response is stored as a snapshot when SETUP decoding completes.

Longer stored responses, particularly USB descriptors, are read from the Hub
Descriptor RAM.

Requests belonging to the USB Hub Class are dispatched to
`usb_app_hw_hub_1` using the decoded request code, `wValue`, and `wIndex`.

The handler also selects the source of EP0 response data:

```text
Standard-request response
Hub Class response
Descriptor or stored response data
```

During SETUP-table decoding, the handler actively controls the Hub Descriptor
RAM interface. During a subsequent EP0 IN data stage, the endpoint data
manager initiates the read and the handler acts as the EP0 response gateway
and response-source multiplexer.

---

### `usb_ep_config_handler_1` - Hub Endpoint Context Manager

**Entity:** `usb_ep_config_handler`  
**Source:** `RTL/usb_ep_config_handler.m.vhdl`  
**Clock domain:** `hclk`

`usb_ep_config_handler_1` maintains the runtime context of the register-based
Hub endpoints:

- Hub EP0 OUT;
- Hub EP0 IN;
- Hub Status Change EP1 IN.

After the EP0 handler completes SETUP decoding, the context manager captures:

- EP0 IN and OUT active state;
- transfer direction;
- transfer byte count;
- response or data-buffer selection.

For Hub EP1 IN, the context manager receives buffer availability, clear,
size, and stall information from the Hub controller.

The block stores current endpoint runtime information, including:

- active state;
- disabled state;
- stall state;
- byte count;
- buffer state;
- toggle-reset-related state.

The stored information is formatted into the common endpoint-context
representation expected by `usb_dma_1`.

When the endpoint data manager reads Hub address region `11`, the block
returns the addressed endpoint-context entry. The endpoint data manager then
decodes that entry into the individual `epinfo_*` signals returned to the
PIE.

The same interface supports writes from `usb_dma_1`, allowing the endpoint
data manager to update the Hub endpoint state as a transfer progresses.

Architecturally, this block adapts the register-based Hub endpoint
implementation to the same endpoint-context model used by the RAM-based
software devices.

---

### `usb_app_hw_hub_1` - Two-Port Hub Controller

**Entity:** `usb_app_hw_hub`  
**Source:** `RTL/usb_app_hw_hub.m.vhdl`  
**Clock domain:** `hclk`  
**Configuration:** two downstream ports

`usb_app_hw_hub_1` implements the USB Hub Class behavior and the operational
control of the two downstream ports.

The port mapping is:

```text
Hub Port 1: DEV0
Hub Port 2: DEV1
```

For Hub Class requests received through EP0, the controller:

- interprets Hub and Port class requests;
- selects the target port using `wIndex`;
- reads or updates Hub and port state;
- generates Hub or Port status response data;
- applies port feature set and clear operations;
- generates downstream port-reset pulses.

The controller receives the downstream soft-connect indication of each
software device. It maintains independent state for each port, including:

- connection status;
- connection-change indication;
- enable state;
- reset-change indication.

A port reset generates a pulse toward the corresponding software-device
reset path and places the port in the enabled state.

The controller also implements the Hub Status Change Interrupt endpoint,
Hub EP1 IN. When a port status-change condition is pending, the controller:

- marks the EP1 IN report as available;
- communicates EP1 IN context updates to the Hub Endpoint Context Manager;
- generates the status-change bitmap returned to the endpoint data manager.

The controller therefore has two independent USB data roles:

- generation of Hub Class response data for EP0 IN;
- direct generation of the Hub Status Change payload for EP1 IN.

---

### Hub Function Resource Decoder and Response Mux

**Implementation:** top-level combinational logic

The Hub function access path is divided into address regions using
`upd_dma_addr[16:15]`:

```text
00: Hub EP0 data and response access
01: Hub Status Change EP1 IN payload access
10: Unimplemented
11: Hub endpoint context access
```

The logic demultiplexes the request toward:

- `hub_ep0_handler_1`;
- `usb_app_hw_hub_1`;
- `usb_ep_config_handler_1`.

Address, write control, and write data remain common where required. Only the
appropriate regional request is asserted.

Grant and read-data responses from the three implemented destinations are
multiplexed back onto the common `upd_dma_*` response path.

The decoder contains no state or arbitration.

---

### `hub_desc_ahb_dma_slave` - Hub Descriptor RAM Access Adapter

**Entity:** `ahb_dma_slave`  
**Source:** `RTL/ahb_dma_slave.m.vhdl`  
**Clock domain:** `hclk`

`hub_desc_ahb_dma_slave` connects the Hub Descriptor RAM to two requesters:

- the internal read-only request generated by the Hub EP0 handler;
- the external Hub Descriptor RAM AHB interface.

The internal Hub EP0 requester has priority over an external AHB request.
When an internal read is active, an external AHB access can be delayed using
the AHB ready response.

The adapter performs:

- internal-request and external-AHB arbitration;
- AHB wait-state generation;
- byte-address to native RAM-address conversion;
- write-data alignment;
- write-selection mask generation;
- read-data selection;
- native RAM control generation.

The internal EP0 path is read-only. External AHB accesses can read and write
the Hub Descriptor RAM.

---

### Hub Descriptor RAM

The external Hub Descriptor RAM stores the data required by the hardware Hub
EP0 implementation.

Its contents include:

- USB descriptors and other stored EP0 response data;
- the Hub SETUP request decode table;
- request comparison patterns and masks;
- internal request identifiers;
- response and data-buffer references.

The RAM does not store the runtime endpoint context of Hub EP0 or Hub EP1 IN.
That state is maintained by `usb_ep_config_handler_1`.

The eight-byte SETUP packet received from the USB bus is also not stored in
this RAM. It is stored in internal registers within `hub_ep0_handler_1`.

---

## Software-Device Control Subsystems

### `usb_reg_if_1/2` - DEV0/DEV1 USB Register Controllers

**Entity:** `usb_reg_if`  
**Source:** `RTL/usb_reg_if.m.vhdl`  
**Clock domain:** `hclk`

`usb_reg_if_1` and `usb_reg_if_2` implement independent software-visible
control and status registers for DEV0 and DEV1.

Each instance maintains:

- current and temporary USB address;
- local function-enable state;
- downstream soft-connect state;
- hardware-set, software-cleared SETUP-pending state;
- Endpoint List base address;
- data-buffer base address;
- endpoint skip state;
- current buffer selection;
- endpoint data-toggle state;
- device, endpoint, frame, error, and bus-event status;
- interrupt status, enable, and routing;
- independent IRQ and FIQ outputs.

When a SETUP packet is received for the selected software device, the
corresponding register controller:

- sets its SETUP-pending state;
- captures the USB address used for the transaction;
- initializes the temporary address to the same value;
- initializes the EP0 IN and OUT toggle state.

The SETUP-pending state remains asserted until cleared by software. While the
flag is set, `usb_dma_1` reports EP0 as inactive and not stalled, causing the
PIE to return NAK to subsequent EP0 transactions. This allows software time
to read and decode the SETUP packet, configure the response buffer, and
prepare the next control-transfer stage.

The current and temporary addresses are supplied to the PIE for function
address matching. During `SET_ADDRESS`, the temporary address can differ from
the current address so that the protocol engine can support the address
transition.

The register controllers do not contain the complete endpoint context. They
maintain compact endpoint-control state, while the detailed endpoint entries
and payload data reside in the corresponding Endpoint RAM.

`usb_reg_if_1`, associated with DEV0, additionally owns the common USB link,
PHY, LPM, test, wake-up, and VBUS control outputs used by the shared PIE and
the top-level integration logic.

The corresponding outputs exist formally in `usb_reg_if_2`, because the same
entity is instantiated, but the outputs are not connected in the current
top-level implementation.

---

### `usb_ahb_slave_1/2` - DEV0/DEV1 AHB-to-Register Adapters

**Entity:** `usb_ahb_slave`  
**Source:** `RTL/usb_ahb_slave.m.vhdl`  
**Clock domain:** `hclk`

`usb_ahb_slave_1` and `usb_ahb_slave_2` convert the external DEV0 and DEV1
control AHB interfaces into the internal register-file interface used by the
corresponding `usb_reg_if` instance.

Each adapter performs:

- AHB transfer qualification;
- register read-address generation;
- register write-address generation;
- register write dispatch;
- register read-data return;
- fixed AHB `OKAY` response generation.

The register path operates without inserted wait states.

These adapters provide access only to the software-visible USB control
registers. Endpoint RAM access is provided through separate AHB interfaces
and separate RAM access adapters.

---

### `ahb_dma_slave_1/2` - DEV0/DEV1 Endpoint RAM Access Adapters

**Entity:** `ahb_dma_slave`  
**Source:** `RTL/ahb_dma_slave.m.vhdl`  
**Clock domain:** `hclk`

`ahb_dma_slave_1` and `ahb_dma_slave_2` connect the DEV0 and DEV1 Endpoint
RAMs to:

- the internal shared endpoint data manager;
- the corresponding external Endpoint RAM AHB interface.

The adapters arbitrate between internal USB access and external AHB access.
Internal USB requests have priority. An external AHB transaction is delayed
when the RAM is being used by the internal endpoint data path.

Each adapter performs:

- internal USB DMA and external AHB arbitration;
- AHB wait-state generation;
- byte-address to native RAM-address conversion;
- write-data alignment;
- DWORD and byte-lane selection;
- native RAM chip-select and write-enable generation;
- read-data return.

The selected-function routing logic asserts only one of the DEV0 or DEV1
internal RAM requests. Address, write control, and write data can be
distributed to both adapters, while the request signal determines the active
target. Grant and read data are selected from the active adapter and returned
to `usb_dma_1`.

---

### DEV0/DEV1 Endpoint RAMs

DEV0 and DEV1 use two independent external Endpoint RAM instances.

Each RAM stores:

- the Endpoint List;
- detailed endpoint transfer contexts;
- endpoint buffer addresses and transfer parameters;
- TX payload buffers;
- RX payload buffers.

The internal endpoint data manager reads endpoint context and TX data from
the selected RAM and writes received RX data and endpoint-state updates back
to that RAM.

The external AHB interfaces allow the system to:

- initialize EP0 and the other endpoint entries;
- configure endpoint type, active state, packet size, and buffer location;
- write TX payload data;
- read received RX payload data;
- inspect endpoint state during debug.

---

## Hub Control Subsystem

### `hub_usb_ahb_slave_1` - Hub AHB-to-Register Adapter

**Entity:** `usb_ahb_slave`  
**Source:** `RTL/usb_ahb_slave.m.vhdl`  
**Clock domain:** `hclk`

`hub_usb_ahb_slave_1` converts the external Hub Control AHB interface into
the internal `hub_reg_*` register-access interface.

The adapter provides:

- AHB transfer qualification;
- register address generation;
- register write dispatch;
- register read-data return;
- zero-wait-state operation;
- fixed AHB `OKAY` response generation.

The adapter does not contain the Hub control register itself. The register is
implemented by top-level sequential and combinational logic.

---

### Hub Control Register

**Implementation:** top-level logic  
**Clock domain:** `hclk`

The Hub Control Register contains two software-controlled fields:

```text
Hub Function Enable
Hub Upstream Soft Connect
```

The register is accessed through `hub_usb_ahb_slave_1` and the internal
`hub_reg_*` interface.

The effective Hub-mode enable is generated from the software Hub-enable bit
and the synchronized external `USB_EnableHub` input.

The effective Hub upstream connection is qualified by the debounced VBUS
state.

The resulting Hub control state is used to:

- enable the Hub function context presented to the PIE;
- select the Hub upstream connect path;
- enable Hub-mode qualification of DEV0 and DEV1;
- select Hub port-reset routing;
- select Hub or non-Hub operating behavior.

Architecturally, the register and the associated connection logic form the
Hub equivalent of the local enable and soft-connect controls present in the
DEV0 and DEV1 register controllers.

---

## Clock, Reset, and Power-Control Logic

**Implementation:** top-level logic  
**Clock domains:** `hclk`, UTMI/ULPI clocks, and `pie_clk`

The Clock, Reset, and Power-Control logic manages the integration of the USB
protocol and system clock domains.

Its responsibilities include:

- UTMI or ULPI clock selection for `pie_clk`;
- asynchronous reset assertion and synchronized PIE reset release;
- UTMI reset and suspend control;
- VBUS debounce;
- low-power and clock-stop handling;
- USB clock-request generation;
- suspend, resume, and wake-up coordination.

The logic receives system reset, UTMI and ULPI clock/status information, VBUS
state, PIE low-power state, and system wake-up control.

It provides:

- `pie_clk` and the synchronized PIE reset;
- debounced VBUS status;
- UTMI reset and suspend controls;
- USB clock and wake-up requests toward the SoC.

The USB bus reset detected by the PIE is separately transferred into the
`hclk` domain by `usb_synchronizer_1`. The synchronized bus-reset event
realigns the Hub and software-device architectural state, including USB
addresses, endpoint contexts, control-transfer state, and software-visible
status.

---

## Architectural Notes

- The PIE selects one USB function for each accepted transaction.
- Hub, DEV0, and DEV1 share the PIE, synchronizer, and endpoint data manager.
- The Hub uses register-based endpoint context and hardware-generated
  responses.
- DEV0 and DEV1 use independent RAM-based endpoint contexts and payload
  buffers.
- The Hub EP0 handler processes only the embedded Hub control endpoint.
- Hub EP1 IN is implemented directly by the Hub controller and does not use a
  dedicated payload RAM.
- DEV0 owns the common USB/PHY control outputs used by the shared
  architecture.
- Function selection, context selection, SETUP routing, Endpoint RAM
  selection, and DMA update routing are implemented in top-level logic.
- Internal USB accesses have priority over external AHB accesses to the three
  external RAMs.
- The architecture diagram intentionally represents some top-level signal
  paths as functional connections rather than reproducing every intermediate
  RTL net.

---

## Functional Interfaces

This section describes the main functional interfaces shown in the
architecture diagram.

The interfaces are presented following the main operating flow:

```text
PIE
  -> Clock-Domain Bridge
  -> Endpoint Data Manager
  -> Hub or software-device path
  -> Endpoint context, response logic, or Endpoint RAM
```

Signal names follow the convention used in the architecture diagram. When a
prefix is shown once in bold, the following names beginning with an
underscore inherit the same prefix.

The following notation is used:

```text
signal_name
  Single-bit signal

signal_name[MSB:LSB]
  Fixed-width vector

signal_name[GENERIC-1:0]
  Generic-dependent vector

signal_name
  Type: integer, range ...
  VHDL integer signal
```

Some connections are represented functionally rather than reproducing every
intermediate top-level net. These simplifications are identified explicitly
where relevant.

---

### USB Function Selection Context

**Direction:** Top-level function-context logic to `usb_pie_1`

This interface provides the PIE with the enable and address state of the
three USB functions.

```text
usbreg_deviceenabled[C_NBDEV+1:0]
pie_dev_addr[(C_NBDEV+2)*7-1:0]
pie_dev_addr_tmp[(C_NBDEV+2)*7-1:0]
```

At the `usb_pie_1` component boundary, the address vectors are connected to:

```text
usbreg_usbaddress[(C_NBDEV+2)*7-1:0]
usbreg_usbaddress_tmp[(C_NBDEV+2)*7-1:0]
```

In the current integration, three functions are exposed to the PIE:

```text
Index 0: Embedded Hub
Index 1: DEV0
Index 2: DEV1
```

The resulting address vectors contain three seven-bit fields:

```text
pie_dev_addr[6:0]
  Hub current address

pie_dev_addr[13:7]
  DEV0 current address

pie_dev_addr[20:14]
  DEV1 current address
```

The same mapping applies to `pie_dev_addr_tmp`.

- `usbreg_deviceenabled` indicates which USB functions are currently
  eligible for PIE address matching and selection.
- `pie_dev_addr` contains the current seven-bit USB address of each function.
- `pie_dev_addr_tmp` contains the corresponding temporary address used
  during `SET_ADDRESS` processing.

In Hub mode, the effective software-device enables are generated by
top-level logic:

```text
DEV0 effective enable =
  DEV0 local function enable AND hub_port_enable[0]

DEV1 effective enable =
  DEV1 local function enable AND hub_port_enable[1]
```

The Hub entry is derived from the Hub connection and operating-mode state.

---

### Selected USB Function

**Direction:** `usb_pie_1` to top-level selected-function routing  
**CDC path:** through `usb_synchronizer_1`

```text
pie_dev_selected
Type: integer, range 0 to C_NBDEV+1

sync_pie_dev_selected
Type: integer, range 0 to C_NBDEV+1
```

- `pie_dev_selected` identifies the USB function selected by the PIE after
  effective-enable and address matching.
- `sync_pie_dev_selected` is the corresponding function index transferred
  into the `hclk` domain.

The current encoding is:

```text
0: Embedded Hub
1: DEV0
2: DEV1
```

`sync_pie_dev_selected` controls:

- Hub versus software-device DMA-path selection;
- DEV0 versus DEV1 Endpoint RAM selection;
- function-context selection for `usb_dma_1`;
- SETUP-event routing;
- DMA endpoint-state update routing;
- grant and read-data response selection.

The architecture diagram may show this connection as a direct functional
input to the top-level routing block. In the RTL, `pie_dev_selected` crosses
`usb_synchronizer_1` before being used by the `hclk`-domain routing logic.

---

### PIE Transaction and Transfer Interface

**Connection:** `usb_pie_1` and `usb_dma_1`  
**CDC path:** through `usb_synchronizer_1`

This bidirectional interface carries endpoint requests, endpoint context,
payload data, and transfer results between the PIE and the Endpoint Data
Manager.

#### PIE to Endpoint Data Manager

```text
sync_sieint_epinfo_req
sync_sieint_epinfo_epnr[3:0]
sync_sieint_epinfo_epdir
sync_sieint_epinfo_setup

sync_sieint_txdatafetched

sync_sieint_rx_nbytes[11:0]
sync_sieint_rxdata[USB_DATAWIDTH-1:0]
sync_sieint_rxdatavalid

sync_sieint_endtransfer
sync_sieint_success
sync_sieint_sentNAK

sync_busreset
sync_pie_speed[1:0]
```

- `sync_sieint_epinfo_req` requests the context of the endpoint involved in
  the current transaction.
- `sync_sieint_epinfo_epnr[3:0]` identifies the endpoint number.
- `sync_sieint_epinfo_epdir` identifies the endpoint direction.
- `sync_sieint_epinfo_setup` distinguishes a SETUP transaction from a normal
  EP0 OUT transaction.
- `sync_sieint_txdatafetched` indicates that the PIE has consumed transmitted
  data supplied by the Endpoint Data Manager.
- `sync_sieint_rx_nbytes[11:0]` reports the number of bytes received from the
  USB bus.
- `sync_sieint_rxdata[USB_DATAWIDTH-1:0]` carries received payload data.
- `sync_sieint_rxdatavalid` qualifies the received payload data.
- `sync_sieint_endtransfer` identifies the end of the current transfer.
- `sync_sieint_success` reports successful transfer completion.
- `sync_sieint_sentNAK` reports that the PIE generated a NAK response.
- `sync_busreset` reports a USB bus-reset event in the `hclk` domain.
- `sync_pie_speed[1:0]` reports the current USB operating speed.

#### Endpoint Data Manager to PIE

```text
epinfo_sync_valid
epinfo_sync_active
epinfo_sync_disabled
epinfo_sync_toggle
epinfo_sync_stall
epinfo_sync_iso
epinfo_sync_ratefeedbackmode
epinfo_sync_nbytes[14:0]
epinfo_sync_maxpacket[1:0]
epinfo_sync_txdata[USB_DATAWIDTH-1:0]
epinfo_sync_txdata_valid
```

- `epinfo_sync_valid` indicates that the requested endpoint context is
  available.
- `epinfo_sync_active` indicates that the endpoint is ready for the requested
  transaction.
- `epinfo_sync_disabled` indicates that the endpoint is disabled.
- `epinfo_sync_toggle` provides the current DATA0/DATA1 state.
- `epinfo_sync_stall` requests a STALL response for the endpoint.
- `epinfo_sync_iso` identifies isochronous endpoint behavior.
- `epinfo_sync_ratefeedbackmode` identifies rate-feedback endpoint behavior.
- `epinfo_sync_nbytes[14:0]` reports the number of bytes available or
  expected for the transfer.
- `epinfo_sync_maxpacket[1:0]` provides encoded maximum-packet information.
- `epinfo_sync_txdata[USB_DATAWIDTH-1:0]` carries data to be transmitted by
  the PIE.
- `epinfo_sync_txdata_valid` qualifies the transmitted data.

After crossing `usb_synchronizer_1`, the `epinfo_sync_*` signals are
presented to `usb_pie_1` through the corresponding `epinfo_*` ports.

For a SETUP transaction, `sync_sieint_epinfo_setup` causes `usb_dma_1` to
apply special EP0 handling, including an eight-byte transfer size and SETUP
buffer selection.

---

### SETUP Packet Received Event

**Direction:** `usb_pie_1` to selected-function routing  
**CDC path:** through `usb_synchronizer_1`

```text
pie_epinfo_setup_received
sync_sieint_setup_received
```

- `pie_epinfo_setup_received` indicates that a valid eight-byte SETUP packet
  has been received and accepted.
- `sync_sieint_setup_received` is the corresponding single-cycle event in the
  `hclk` domain.

This event is distinct from `epinfo_setup`:

```text
epinfo_setup
  Identifies the current transaction as SETUP and controls the DMA data path.

setup_received
  Indicates that the complete eight-byte SETUP packet is available for
  processing by the selected USB function.
```

Top-level logic routes the event according to `sync_pie_dev_selected`:

```text
Hub selected:
  SETUP-decode trigger to hub_ep0_handler_1

DEV0 selected:
  dev0_setup_received to usb_reg_if_1

DEV1 selected:
  dev1_setup_received to usb_reg_if_2
```

For the Hub, the RTL converts the event into:

```text
usbreg_setup_to_decode[C_NBDEV-1:0]
```

In the current integration, only:

```text
usbreg_setup_to_decode[0]
```

is used because the Hub is the only hardware-controlled USB function.

The pending indication remains asserted until:

```text
ep0_setupdone[0]
```

is returned by the Hub EP0 handler.

The architecture diagram may show a simplified direct SETUP trigger into the
Hub EP0 handler. This represents the functional behavior while omitting the
top-level pending-flag round trip.

---

### Selected Function Context

**Direction:** top-level selected-function routing to `usb_dma_1`

```text
dma_ep_list_start[23:0]
dma_data_buffer_start[31:C_DALB]
dma_ep_skip_selected[C_NBPHYSEP_ARM+1:0]
dma_ep_bufinuse_selected[C_NBPHYSEP_ARM+1:0]
dma_epinfo_toggle[C_NBPHYSEP_ARM+1:0]
usbreg_setup_to_dma
```

The signals connect to the following `usb_dma_1` ports:

```text
dma_ep_list_start[23:0]
  -> usbreg_ep_list_start[31:8]

dma_ep_list_start[23:0]
  -> usbreg_ep_skip_list_start[31:8]

dma_data_buffer_start[31:C_DALB]
  -> usbreg_data_buffer_start[31:C_DALB]

dma_ep_skip_selected[C_NBPHYSEP_ARM+1:0]
  -> usbreg_ep_skip[C_NBPHYSEP+1:0]

dma_ep_bufinuse_selected[C_NBPHYSEP_ARM+1:0]
  -> usbreg_ep_bufinuse[C_NBPHYSEP+1:0]

dma_epinfo_toggle[C_NBPHYSEP_ARM+1:0]
  -> usbreg_epinfo_toggle[C_NBPHYSEP+1:0]

usbreg_setup_to_dma
  -> usbreg_setup
```

- `dma_ep_list_start[23:0]` supplies the upper address portion of the selected
  Endpoint List.
- The same value supplies the Endpoint Skip List base in the current
  integration.
- `dma_data_buffer_start[31:C_DALB]` supplies the high-order data-buffer base
  address.
- `dma_ep_skip_selected` provides the endpoint skip state of the selected
  function.
- `dma_ep_bufinuse_selected` identifies the active buffer for each endpoint.
- `dma_epinfo_toggle` provides the current data-toggle state.
- `usbreg_setup_to_dma` reports whether a software-controlled SETUP request
  remains pending.

For DEV0 and DEV1, these values are selected from the corresponding
`usb_reg_if` instance.

For the Hub, top-level logic supplies predefined mapping values that allow
`usb_dma_1` to reach the dedicated Hub resources. The actual Hub endpoint
runtime state is subsequently read from `usb_ep_config_handler_1`.

While a selected software device has an uncleared SETUP request,
`usb_dma_1` reports EP0 as inactive and not stalled. This causes the PIE to
return NAK until software has prepared the next control-transfer stage.

---

### Endpoint Memory and State Context

**Direction:** `usb_reg_if_1/2` to top-level selected-function routing

#### DEV0 component-level outputs

```text
usbreg_ep_list_start[31:0]
usbreg_data_buffer_start[31:0]
usbreg_ep_skip[C_NBPHYSEP+1:0]
usbreg_ep_bufinuse[C_NBPHYSEP+1:0]
usbreg_epinfo_toggle[C_NBPHYSEP+1:0]
usbreg_setup
```

#### DEV1 top-level signals

```text
dev1_usbreg_ep_list_start[31:0]
dev1_usbreg_data_buffer_start[31:0]
dev1_usbreg_ep_skip[C_NBPHYSEP_ARM+1:0]
dev1_usbreg_ep_bufinuse[C_NBPHYSEP_ARM+1:0]
dev1_usbreg_epinfo_toggle[C_NBPHYSEP_ARM+1:0]
dev1_usbreg_setup
```

- `usbreg_ep_list_start[31:0]` supplies the Endpoint List base address.
- `usbreg_data_buffer_start[31:0]` supplies the payload-buffer base address.
- `usbreg_ep_skip` supplies the per-endpoint skip state.
- `usbreg_ep_bufinuse` selects the current buffer for each endpoint.
- `usbreg_epinfo_toggle` supplies the current endpoint toggle state.
- `usbreg_setup` indicates that the received SETUP packet remains pending for
  software processing.

The top-level context mux selects the appropriate fields and produces the
Selected Function Context presented to `usb_dma_1`.

There is no directly equivalent Hub interface from a Hub register
controller. Hub-specific address mapping is generated by top-level logic,
while the actual Hub endpoint context is maintained by
`usb_ep_config_handler_1`.

---

### DMA Endpoint-State Update Interface

**Direction:** `usb_dma_1` to selected `usb_reg_if`

```text
dma_clear_toggle
dma_set_toggle
dma_sent_NAK
dma_set_int

dma_physepnr
Type: integer, range 0 to C_NBPHYSEP+1

dma_clear_skip

dma_skip_ep
Type: integer, range 0 to C_NBPHYSEP+1
```

- `dma_clear_toggle` clears the toggle state of the addressed endpoint.
- `dma_set_toggle` sets the toggle state of the addressed endpoint.
- `dma_sent_NAK` reports a NAK associated with the transfer.
- `dma_set_int` sets the interrupt state of the addressed endpoint.
- `dma_physepnr` identifies the physical endpoint affected by the update.
- `dma_clear_skip` clears an endpoint skip indication.
- `dma_skip_ep` identifies the endpoint whose skip state is updated.

Top-level logic qualifies the update strobes separately for DEV0 and DEV1:

```text
dev0_dma_clear_toggle
dev0_dma_set_toggle
dev0_dma_sent_nak
dev0_dma_set_int
dev0_dma_clear_skip
```

```text
dev1_dma_clear_toggle
dev1_dma_set_toggle
dev1_dma_sent_nak
dev1_dma_set_int
dev1_dma_clear_skip
```

`dma_physepnr` and `dma_skip_ep` remain common endpoint indices.

Hub endpoint updates do not use this dedicated interface. The Hub uses
memory-mapped writes through the Hub Endpoint Context Access interface to
update `usb_ep_config_handler_1`.

---

### Shared Endpoint Access

**Connection:** `usb_dma_1` and `usb_fs_mux_1`

```text
dma_dma_addr[31:0]
dma_dma_req
dma_dma_write
dma_dma_wdata[RAM_DATAWIDTH-1:0]

dma_dma_gnt
dma_dma_rdata[RAM_DATAWIDTH-1:0]
```

#### Endpoint Data Manager to Path Mux

- `dma_dma_addr[31:0]` identifies the endpoint-context or payload resource.
- `dma_dma_req` requests the access.
- `dma_dma_write` distinguishes a write from a read.
- `dma_dma_wdata[RAM_DATAWIDTH-1:0]` carries write data.

#### Path Mux to Endpoint Data Manager

- `dma_dma_gnt` acknowledges or completes the selected access.
- `dma_dma_rdata[RAM_DATAWIDTH-1:0]` returns data from the selected resource.

At the `usb_dma_1` boundary, the equivalent ports are:

```text
dma_addr[31:0]
dma_req
dma_write
dma_wdata[RAM_DATAWIDTH-1:0]
dma_word_enable[RAM_DATAWIDTH/32-1:0]

dma_gnt
dma_rdata[RAM_DATAWIDTH-1:0]
```

`dma_word_enable` is carried separately toward the software-device RAM
adapters and identifies the valid 32-bit portions of the RAM transfer.

`usb_fs_mux_1` routes the request toward the Hub path or the
software-device RAM path. The two request paths are mutually exclusive.

---

### Hub versus Software-Device Path Select

**Direction:** selected-function logic to `usb_fs_mux_1`

```text
dma_ahb_selected
```

- `dma_ahb_selected = 0` selects the Hub function path, `upd_dma_*`.
- `dma_ahb_selected = 1` selects the software-device RAM path, `ahb_dma_*`.

The signal is derived from `sync_pie_dev_selected`. It is not independently
generated by `usb_fs_mux_1`.

---

### Hub Function Access

**Connection:** `usb_fs_mux_1` and the Hub resource decoder

```text
upd_dma_addr[31:0]
upd_dma_req
upd_dma_write
upd_dma_wdata[RAM_DATAWIDTH-1:0]

upd_dma_gnt
upd_dma_rdata[RAM_DATAWIDTH-1:0]
```

#### Path Mux to Hub Resources

- `upd_dma_addr[31:0]` selects the Hub resource and the location within that
  resource.
- `upd_dma_req` requests a Hub access.
- `upd_dma_write` indicates a Hub-side write operation.
- `upd_dma_wdata[RAM_DATAWIDTH-1:0]` carries write data.

#### Hub Resources to Path Mux

- `upd_dma_gnt` acknowledges or completes the access.
- `upd_dma_rdata[RAM_DATAWIDTH-1:0]` returns endpoint context or payload data.

The Hub address-region bits select:

```text
upd_dma_addr[16:15]

00: Hub EP0 data and response access
01: Hub Status Change EP1 IN payload access
10: Unimplemented
11: Hub endpoint context access
```

`upd_dma_write` and `upd_dma_wdata` are used for:

- storage of the eight-byte SETUP packet in `hub_ep0_handler_1`;
- runtime Hub endpoint-context updates in `usb_ep_config_handler_1`.

The Hub EP1 IN payload path is read-only.

---

### Hub EP0 Data Access

**Connection:** Hub resource decoder and `hub_ep0_handler_1`

#### Toward `hub_ep0_handler_1`

```text
upd_dma_addr[14:0]
upd_dma_req_ep0
upd_dma_write
upd_dma_wdata[RAM_DATAWIDTH-1:0]
```

#### From `hub_ep0_handler_1`

```text
upd_dma_gnt_ep0
upd_dma_rdata_ep0[RAM_DATAWIDTH-1:0]
```

- `upd_dma_req_ep0` qualifies an access to Hub address region `00`.
- `upd_dma_addr[14:0]` identifies the selected EP0 storage or response
  location.
- `upd_dma_write` and `upd_dma_wdata` store the received SETUP packet when
  the address identifies the SETUP storage area.
- `upd_dma_gnt_ep0` acknowledges the access.
- `upd_dma_rdata_ep0` returns the selected EP0 response data.

Within the Hub EP0 region:

```text
upd_dma_addr[14]
```

qualifies the internal SETUP-packet storage area for DMA writes.

For EP0 response reads, address bits `[13:12]` select:

```text
00: Standard-request response generated by the EP0 handler
01: Hub Class response generated by the Hub controller
1x: Descriptor or stored response read from Hub Descriptor RAM
```

The response sources are selected exclusively. Data from different sources
is not combined within one response.

---

### Hub SETUP Decode Trigger

**Direction:** selected-function SETUP routing to `hub_ep0_handler_1`

```text
usbreg_setup_to_decode[C_NBDEV-1:0]
```

Current integration:

```text
usbreg_setup_to_decode[0]
```

- `usbreg_setup_to_decode[0]` indicates that the stored SETUP packet for the
  embedded Hub is pending decoding.

The vector form exists because the source RTL supports an array of
hardware-controlled functions. The current integration contains only one
such function, the embedded Hub.

The pending indication remains asserted until:

```text
ep0_setupdone[0]
```

is returned by `hub_ep0_handler_1`.

The architecture diagram may represent this as a simplified direct
SETUP-received trigger into the Hub EP0 handler.

---

### Hub Descriptor and Response Read

**Connection:** `hub_ep0_handler_1` and `hub_desc_ahb_dma_slave`

#### EP0 handler to RAM adapter

```text
ep0_mem_req
ep0_mem_addr[11:0]
```

#### RAM adapter to EP0 handler

```text
ep0_mem_gnt
ep0_mem_rdata[RAM_DATAWIDTH-1:0]
```

- `ep0_mem_req` requests a read from the Hub Descriptor RAM.
- `ep0_mem_addr[11:0]` provides the DWORD address.
- `ep0_mem_gnt` indicates that the requested data is available.
- `ep0_mem_rdata[RAM_DATAWIDTH-1:0]` returns the selected RAM word.

The interface is read-only from the perspective of `hub_ep0_handler_1`.

The handler uses this interface in two operating modes:

1. autonomous SETUP decode-table access;
2. DMA-initiated descriptor or stored-response access.

During SETUP decoding, the handler generates the RAM requests autonomously.
During an EP0 IN data stage, the DMA initiates the read and the handler acts
as the gateway between the Hub function path and the Descriptor RAM.

---

### Decoded EP0 Transfer Context

**Connection:** `hub_ep0_handler_1` and `usb_ep_config_handler_1`

#### EP0 handler to Context Manager

```text
ep0_setupdone[C_NBDEV-1:0]
ep0_out_active
ep0_in_active
ep0_outin_nbytes[C_EPNBYTEWIDTH-1:0]
ep0_setup_dir
ep0_data_buffer[7:0]
ep0_device_config[C_NBDEV-1:0]
ep_set_stall[C_NBPHYSEP-1:0]
ep_clear_stall[C_NBPHYSEP-1:0]
```

Current Hub completion indication:

```text
ep0_setupdone[0]
```

- `ep0_setupdone` qualifies the completion of SETUP request decoding.
- `ep0_out_active` marks Hub EP0 OUT as active for the prepared transfer.
- `ep0_in_active` marks Hub EP0 IN as active for the prepared transfer.
- `ep0_outin_nbytes` supplies the data-stage length.
- `ep0_setup_dir` supplies the control-transfer direction.
- `ep0_data_buffer[7:0]` identifies the selected response or data source.
- `ep0_device_config` supplies the current Hub configuration state.
- `ep_set_stall` requests that an addressed Hub endpoint be stalled.
- `ep_clear_stall` clears endpoint stall state and resets related toggle
  state.

#### Context Manager to EP0 handler

```text
epconfig_stall[C_NBPHYSEP-1:0]
```

- `epconfig_stall` returns the current Hub endpoint stall state, allowing the
  EP0 handler to generate responses such as `GET_STATUS(Endpoint)`.

When `ep0_setupdone[0]` is asserted, `usb_ep_config_handler_1` captures the
prepared EP0 context into its runtime-state registers.

This event does not directly activate `usb_dma_1`. The DMA accesses the
updated context after the PIE receives the token for the next DATA or STATUS
stage.

---

### Hub Endpoint Context Access

**Connection:** Hub resource decoder and `usb_ep_config_handler_1`

#### Toward the Context Manager

```text
upd_dma_addr[14:0]
upd_dma_req_config
upd_dma_write
upd_dma_wdata[RAM_DATAWIDTH-1:0]
```

#### From the Context Manager

```text
upd_dma_gnt_config
upd_dma_rdata_config[RAM_DATAWIDTH-1:0]
```

- `upd_dma_req_config` qualifies an access to Hub address region `11`.
- `upd_dma_addr[14:0]` identifies the Hub function, endpoint, direction, and
  context entry.
- `upd_dma_write` identifies a runtime-state update.
- `upd_dma_wdata` carries the updated endpoint state.
- `upd_dma_gnt_config` acknowledges the access.
- `upd_dma_rdata_config` returns the encoded endpoint-context entry.

The interface supports:

- reads of Hub EP0 OUT, EP0 IN, and EP1 IN context;
- writes that update endpoint runtime state after a transfer.

The returned context is decoded by `usb_dma_1` into the `epinfo_*` signals
required by the PIE.

---

### Hub Class Request and Response

**Connection:** `hub_ep0_handler_1` and `usb_app_hw_hub_1`

#### EP0 handler to Hub Controller

```text
ep0_setupdone
ep0_request[6:0]
ep0_wvalue[15:0]
ep0_windex[15:0]
```

At the top-level connection, the single Hub completion input is driven by:

```text
ep0_setupdone[0]
```

- `ep0_setupdone` qualifies the decoded request information.
- `ep0_request[6:0]` contains the internal request identifier obtained from
  the SETUP decode table.
- `ep0_wvalue[15:0]` carries the original SETUP `wValue`.
- `ep0_windex[15:0]` carries the original SETUP `wIndex` and identifies the
  target downstream port for port requests.

#### Hub Controller to EP0 handler

```text
ep0_class_rdata[RAM_DATAWIDTH-1:0]
```

- `ep0_class_rdata` provides the complete single-word response for supported
  Hub Class read requests.

The Hub controller receives each qualified decoded request but performs a
Hub operation only when `ep0_request` identifies a supported Hub or Port
class request.

`ep0_class_rdata` is not stored by the EP0 handler. The EP0 handler selects
the response combinationally when `usb_dma_1` later requests the EP0 IN data.

The EP0 handler also defines:

```text
ep0_class_addr[3:0]
```

but this output is left unconnected in the current top-level integration.
Consequently, the connected Hub Class response mechanism is effectively
single-word.

---

### Hub EP1 IN Context Control

**Direction:** `usb_app_hw_hub_1` to `usb_ep_config_handler_1`

#### Hub Controller outputs

```text
hub_epin_stall
hub_epin_clear_buffer
hub_epin_enable_buffer
hub_epin_buffer_size[6:0]
```

#### Corresponding Context Manager inputs

```text
ep_stall[0]
ep_clear_buffer[0]
ep_enable_buffer[0]
ep_buffer_size[6:0]
```

- `hub_epin_stall` supplies the STALL state of Hub EP1 IN.
- `hub_epin_enable_buffer` indicates that a new Hub Status Change report is
  available.
- `hub_epin_clear_buffer` indicates that the current report is consumed or
  must be released.
- `hub_epin_buffer_size[6:0]` supplies the number of valid bytes in the
  report.

The top-level maps the signals to endpoint-context entry `0`, which
represents the single non-control hardware endpoint, Hub EP1 IN.

This interface is functionally similar to the EP0 transfer context supplied
by the EP0 handler. Both interfaces update register-based endpoint state
maintained by `usb_ep_config_handler_1`.

---

### Hub Status Change EP1 IN Access

**Connection:** Hub resource decoder and `usb_app_hw_hub_1`

#### Top-level request toward the Hub Controller

```text
upd_dma_req_ep_hub
upd_dma_addr[4:2]
```

#### Component-level inputs

```text
hub_epin_req
hub_epin_addr[2:0]
```

#### Component-level outputs

```text
hub_epin_gnt
hub_epin_rdata[RAM_DATAWIDTH-1:0]
```

#### Top-level response signals

```text
upd_dma_gnt_ep_noram
upd_dma_rdata_ep_noram[RAM_DATAWIDTH-1:0]
```

- `upd_dma_req_ep_hub` is generated when Hub address region `01` is selected.
- `upd_dma_addr[4:2]` selects the required word or data position.
- `hub_epin_gnt` acknowledges the read.
- `hub_epin_rdata` contains the Hub Status Change bitmap.

This path does not pass through `hub_ep0_handler_1` and does not use a
dedicated payload RAM.

The operation is distinct from an EP0 Hub Class response:

```text
Hub Class status response:
  EP0 IN through ep0_class_rdata and hub_ep0_handler_1

Hub Status Change notification:
  EP1 IN directly through hub_epin_rdata
```

---

### Hub Downstream-Port Control and Status

**Connection:** `usb_app_hw_hub_1`, DEV0, DEV1, and top-level routing

```text
hub_port_connect
