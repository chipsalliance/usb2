# JANUS USB 2.0 Compound Device IP

## Architecture, Integration, and Operational Guide

JANUS implements a USB 2.0 compound device composed of one embedded two-port
Hub and two software-controlled downstream devices, DEV0 and DEV1.

The three USB functions share one USB Protocol and Interface Engine and one
Endpoint Data Manager, while using different endpoint implementations:

```text
Embedded Hub
  Hardware-managed EP0 and EP1 IN
  External Descriptor RAM

DEV0 and DEV1
  Software-controlled register interfaces
  Independent Endpoint RAMs
```

This document is intended as an architectural, integration, and debug guide.
It describes how to navigate the RTL, connect the IP, understand its control
and data paths, and follow representative USB transactions in simulation.

## Document Structure

### 1. Introduction

Defines the JANUS scope, USB function mapping, terminology, and distinction
between the hardware-managed Hub and the RAM-based software devices.

### 2. Detailed Architecture Diagram

Provides the main visual reference for the complete architecture, including
the shared PIE and DMA, clock-domain crossing, Hub subsystem, DEV0/DEV1
subsystems, routing logic, AHB interfaces, and external RAMs.

### 3. Top-Level Configuration Generics

Describes the parameters controlling PHY support, endpoint resources,
buffering capabilities, memory widths, memory capacity, and address
generation.

### 4. Top-Level Interfaces

Documents the external integration boundary, including clocks, resets,
power-management controls, UTMI and ULPI, AHB interfaces, native RAM
interfaces, interrupts, observation outputs, and test controls.

### 5. RTL Block Descriptions

Explains the role, connectivity, and architectural ownership of each major
RTL block and of the functional logic implemented directly in the top level.

### 6. Internal Functional Interfaces

Describes the main control, endpoint-context, payload, and memory interfaces
between the internal blocks, including signal names, widths, directions, and
routing behavior.

### 7. Operational Flows

Follows representative USB transactions through the architecture:

- standard and descriptor requests to Hub EP0;
- Hub Class requests to Hub EP0;
- Hub Status Change transfers on EP1 IN;
- control transfers to DEV0 or DEV1;
- Bulk IN and Bulk OUT transfers to DEV0 or DEV1.

The flows identify the participating blocks, context lookups, memory
accesses, response paths, runtime-state updates, and principal signals useful
for simulation debug.

## Suggested Reading Paths

```text
Integration:
  Configuration Generics -> Top-Level Interfaces -> Architecture Diagram

RTL development:
  Architecture Diagram -> Block Descriptions -> Functional Interfaces

Verification and debug:
  Architecture Diagram -> Operational Flows -> Debug Observability
```

## Diagram Conventions

```text
Solid block:
  Instantiated RTL component

Dashed block:
  Top-level logic or functional aggregation

Stacked blocks:
  Independent DEV0 and DEV1 instances

Function 0:
  Embedded Hub

Function 1:
  DEV0, connected to Hub Port 1

Function 2:
  DEV1, connected to Hub Port 2
```

Some diagram connections represent functional paths rather than every
intermediate RTL net. The detailed block and interface sections provide the
corresponding implementation-level references.


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

## Top-Level Interfaces

Unless otherwise stated, the dimensions and behavior described in this
section refer to the default JANUS configuration defined in the preceding
Top-Level Configuration Generics section.

Generic expressions are retained where they provide useful integration
information.

### Interface Overview

The JANUS top-level exposes interfaces for:

- system clock, reset, and power-management coordination;
- connection to an external USB 2.0 PHY through UTMI or ULPI;
- independent AHB control of the embedded Hub, DEV0, and DEV1;
- external AHB access to the Hub Descriptor RAM and the DEV0 and DEV1
  Endpoint RAMs;
- native connection to the three external RAM macros or memory models;
- independent DEV0 and DEV1 interrupt reporting;
- static configuration and testability;
- USB frame timing and internal USB DMA write-access observation.

DEV0 and DEV1 expose structurally equivalent control, Endpoint RAM, and
interrupt interfaces. The `dev0_` and `dev1_` prefixes identify the target
software-controlled USB function.

UTMI and ULPI are alternative PHY interfaces. The selected PHY clock is used
as `pie_clk` by the shared USB Protocol and Interface Engine.

---

### Top-Level Interface Diagram

The following diagram groups the JANUS top-level ports by functional
category. Input groups are shown on the left side of the IP boundary, while
output and mixed-direction interface groups are shown on the right side.

images/janus_top_level_interface.png

---

### Interface Categories

| Category | Interfaces | Purpose |
|---|---|---|
| System integration | Clock, reset, clock request, wake-up, VBUS, and analog control | Connects JANUS to the system clocking, reset, power-management, and analog-control infrastructure. |
| USB PHY | UTMI and ULPI | Connects the shared USB PIE to an external USB 2.0 PHY. |
| Host control | Hub, DEV0, and DEV1 AHB register-control interfaces | Allows an external system master to configure and monitor the three USB functions. |
| External memory access | Hub Descriptor RAM and DEV0/DEV1 Endpoint RAM AHB interfaces | Allows an external system master to initialize, inspect, and update the USB memories. |
| Native memory | Hub Descriptor RAM and DEV0/DEV1 Endpoint RAM native interfaces | Connects JANUS to the three external RAM macros or memory models. |
| Interrupt and observation | DEV0/DEV1 IRQ and FIQ, frame toggle, and USB DMA write-access observation | Reports software-device events and exposes selected internal timing and memory-write activity. |
| Configuration and test | Hub configuration, self-powered indication, and DFT controls | Provides static integration configuration and test support. |

---

### Common Interface Conventions

Unless otherwise stated:

- AHB-facing interfaces operate in the `hclk` domain.
- AHB slave front-ends and AHB-to-memory adapters are reset by
  `ahbs_resetn`.
- USB functional logic in the system-side clock domain is reset by
  `hresetn`.
- DEV0 and DEV1 interfaces are structurally equivalent and use the `dev0_`
  and `dev1_` prefixes.
- Native RAM chip-select outputs are active high.
- Native RAM write-enable outputs are active low.
- Native RAM write-selection masks are active high.
- AHB slave interfaces return the two-bit `OKAY` response.
- Unsupported or unimplemented register and memory addresses do not
  generate an AHB error response.
- AHB signals containing `_dma_` in their names remain AHB slave-interface
  signals. The naming is inherited from the internal `ahb_dma_slave` module
  and does not identify an external DMA master.

---

### Clock-Domain Summary

| Domain | Clock | Main Functions |
|---|---|---|
| System-side domain | `hclk` | AHB front-ends, DEV0/DEV1 register interfaces, shared Endpoint Data Manager, memory adapters, Hub control, and top-level control logic |
| USB protocol domain | `pie_clk` | Shared USB PIE, packet processing, USB bus-event control, PHY-side protocol logic, and VBUS debounce |
| UTMI PHY mode | `utmi_clk` | Selected as `pie_clk` when UTMI mode is active |
| ULPI PHY mode | `ulpi_clk` | Selected as `pie_clk` when ULPI mode is active |

---

## System Integration Interfaces

The system integration interfaces connect JANUS to the surrounding clock,
reset, power-management, and analog-control infrastructure.

### Clock and Reset Interface

JANUS provides two independent active-low top-level resets:

- `hresetn` resets the USB functional logic in the `hclk` domain;
- `ahbs_resetn` resets the AHB-facing front-ends, AHB-to-memory adapters,
  and the Hub Control Register.

Both resets are used as asynchronous reset inputs by the corresponding
`hclk`-domain logic. No reset-deassertion synchronizer is present at these
top-level boundaries. The integration environment must therefore ensure
that reset release satisfies the required recovery and removal timing
relative to `hclk`.

Before being applied to the USB protocol domain, `hresetn` passes through a
two-stage reset synchronizer clocked by `pie_clk`. The PIE-domain reset
therefore uses asynchronous assertion and synchronous deassertion.

The resulting PIE reset is generated as:

```text
reset_n = sync_ss_reset_n OR async_disable
```

During normal functional operation, `async_disable` must remain low.

In normal mode, `pie_clk` is selected by the synchronized PHY mode supplied
by the DEV0 register-control path:

```text
phy_mode = 0 -> pie_clk = utmi_clk
phy_mode = 1 -> pie_clk = ulpi_clk
```

In test mode, clock selection depends on the enabled PHY-support generics:

```text
C_UTMI_SUPPORT = TRUE
  -> pie_clk = utmi_clk

otherwise, if C_ULPI_SUPPORT = TRUE
  -> pie_clk = ulpi_clk
```

UTMI has priority when both PHY interfaces are enabled and `testmode` is
asserted.

| Signal | Direction | Width | Active Level | Description |
|---|---:|---:|---|---|
| `hclk` | Input | 1 | Rising edge | Main system-side clock. It clocks the AHB slave interfaces, DEV0 and DEV1 register interfaces, shared Endpoint Data Manager, memory-access adapters, Hub-control logic, and top-level control processes. |
| `hresetn` | Input | 1 | Active low | Asynchronous reset input for the `hclk`-domain USB functional logic. Its deassertion is synchronized before entering the `pie_clk` domain. |
| `ahbs_resetn` | Input | 1 | Active low | Asynchronous reset input for the AHB slave front-ends, AHB-to-memory adapters, and Hub Control Register. |
| `utmi_clk` | Input | 1 | Rising edge | Clock supplied by the UTMI PHY. It is selected as `pie_clk` in normal UTMI mode or when UTMI has priority in test mode. |
| `ulpi_clk` | Input | 1 | Rising edge | Clock supplied by the ULPI PHY. It is selected as `pie_clk` in normal ULPI mode or in test mode when UTMI support is disabled. |
| `sys_utmi_clkin_lock` | Input | 1 | Active high | Indicates that the UTMI input clock is available and stable. It qualifies the UTMI clock-status and low-power transition logic. |

The reset distribution is summarized below:

```text
hresetn
  -> asynchronous reset of hclk-domain USB functional logic
  -> two-stage reset synchronization in the pie_clk domain
  -> reset_n for usb_pie_1

ahbs_resetn
  -> asynchronous reset of AHB slave front-ends
  -> asynchronous reset of AHB-to-memory adapters
  -> asynchronous reset of the Hub Control Register

async_disable
  -> DFT-specific override of selected asynchronous reset and wake-up paths
```

---

### Clock Request and Wake-Up Interface

This interface coordinates USB clock availability and wake-up behavior with
the surrounding system power-management logic.

`usb_needclk` is generated by the top-level Clock, Reset, and Power-Control
logic. Its behavior depends on the selected PHY mode, current USB activity,
clock-shutdown state, availability of asynchronous low-power indications,
and pending internal wake-up requests.

| Signal | Direction | Width | Active Level | Description |
|---|---:|---:|---|---|
| `usb_needclk` | Output | 1 | Active high | Requests that the USB clock remain available or be restarted. |
| `sys_donotwakeup_n` | Input | 1 | Active low | When low, inhibits USB clock and PHY wake-up requests, forces `usb_needclk` low, and requests UTMI suspend. |
| `sys_dev_wakeup_n` | Input | 1 | Active low | External system wake-up request. A low value contributes directly to the internal `clock_on` request. |
| `sys_utmi_clkin_lock` | Input | 1 | Active high | Qualifies UTMI clock availability and the associated low-power control logic. |

In UTMI mode, `usb_needclk` remains asserted while one or more of the
following conditions is present:

- internal USB activity requires the clock;
- the controlled UTMI clock-shutdown interval has not completed;
- asynchronous low-power line-state interpretation is not yet available;
- an internal wake-up request remains pending.

In ULPI mode, the same general conditions apply except that the
UTMI-specific clock-shutdown counter is not part of the request condition.

The top-level wake-up logic can detect changes in the USB line state and ULPI
low-power interrupt indications. A pending wake-up request remains asserted
until the USB clock is running and the PIE has left the low-power state.

---

### VBUS and Analog Control Interface

This interface connects JANUS to the USB VBUS-detection and external
analog-control logic.

`USB_VBus` is supplied to `usb_pie_1`. The PIE exports the corresponding
VBUS-valid state as `pie_vbusvalid`. Top-level logic debounces that state in
the `pie_clk` domain before transferring the filtered result to the `hclk`
domain as `sync_VBusDebounced`.

The functional path is:

```text
USB_VBus
  -> usb_pie_1
  -> pie_vbusvalid
  -> VBUS debounce in pie_clk domain
  -> VBusDebounced
  -> usb_synchronizer_1
  -> sync_VBusDebounced
```

`avalid` and `sessend` provide additional analog and session-status inputs
inherited from the original USB IP. They are synchronized before being used
by the DEV0 and DEV1 register and interrupt logic.

| Signal | Direction | Width | Active Level | Description |
|---|---:|---:|---|---|
| `USB_VBus` | Input | 1 | Active high | External VBUS-present indication supplied to the shared USB PIE. |
| `vbuscomp_on` | Output | 1 | Active high | Enables the external analog VBUS comparator function. |
| `chrg_vbus` | Output | 1 | Active high | Requests charging of VBUS through the external PHY or analog subsystem. |
| `dischrg_vbus` | Output | 1 | Active high | Requests discharging of VBUS through the external PHY or analog subsystem. |
| `avalid` | Input | 1 | Active high | Analog A-valid status input, identified in the RTL as `ADPPROBE`. |
| `sessend` | Input | 1 | Active high | Session-end status input, identified in the RTL as `ADPSENSE`. |

The `vbuscomp_on`, `chrg_vbus`, and `dischrg_vbus` controls originate from
the DEV0 USB Register Controller. `vbuscomp_on` also qualifies the VBUS-valid
sampling used by the debounce logic.

The presence of `avalid`, `sessend`, `chrg_vbus`, and `dischrg_vbus`
reflects capabilities inherited from the original USB IP. Their active use
depends on the selected PHY and the system-level power architecture.

---

## USB PHY Interfaces

JANUS supports external USB PHY connectivity through UTMI or ULPI.

The available PHY implementations are controlled by `C_UTMI_SUPPORT` and
`C_ULPI_SUPPORT`. When both interfaces are enabled, the active PHY mode is
selected through the DEV0 USB register-control path.

Only one PHY interface is active at a time. The selected PHY clock becomes
the shared `pie_clk`.

### UTMI PHY Interface

The UTMI interface connects the shared USB PIE to an external USB 2.0 UTMI
PHY.

> **Implementation note:** The UTMI receive and transmit paths are registered
> in the `pie_clk` domain. PHY operating controls are generated by the PIE
> bus-event logic according to the current USB speed and bus state.

#### UTMI Receive Path

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `utmi_rxdata[7:0]` | Input | 8 | Receive-data bus from the UTMI PHY. |
| `utmi_rxvalid` | Input | 1 | Indicates that `utmi_rxdata[7:0]` contains valid receive data. |
| `utmi_rxactive` | Input | 1 | Indicates that USB packet reception is in progress. |
| `utmi_rxerror` | Input | 1 | Indicates an error in the currently received USB packet. |
| `utmi_linestate[1:0]` | Input | 2 | Current single-ended USB line state. Bit 0 is used as the internal `D+` state and bit 1 as the internal `D-` state. |

A received byte is accepted by the packet-processing logic when
`utmi_rxvalid` and `utmi_rxactive` are high and `utmi_rxerror` is low.

#### UTMI Transmit Path

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `utmi_txdata[7:0]` | Output | 8 | Transmit-data bus from the shared USB PIE to the UTMI PHY. |
| `utmi_txvalid` | Output | 1 | Indicates that valid transmit data is present on `utmi_txdata[7:0]`. |
| `utmi_txready` | Input | 1 | Indicates that the UTMI PHY has accepted the current transmit byte and is ready for the next byte. |

During USB packet and test-packet transmission, `utmi_txdata[7:0]` remains
stable until the PHY asserts `utmi_txready`.

#### UTMI PHY Controls

| Signal | Direction | Width | Active Level or Encoding | Description |
|---|---:|---:|---|---|
| `utmi_reset` | Output | 1 | Active high | Resets the external UTMI PHY. It is generated by the top-level reset-extension logic. |
| `utmi_suspendm` | Output | 1 | Active low | Controls PHY suspend. A low value requests suspend. |
| `utmi_xcvrselect` | Output | 1 | Encoded | Selects the UTMI transceiver. The current RTL drives zero for High-Speed operation and one for Full-Speed operation. |
| `utmi_termselect` | Output | 1 | Encoded | Selects the PHY termination mode. The current RTL drives zero during normal High-Speed operation and one during Full-Speed operation and selected reset, chirp, suspend, and resume states. |
| `utmi_opmode[1:0]` | Output | 2 | Encoded | Selects the PHY operating mode. The PIE uses `00` for normal operation, `01` while disconnected, and `10` during non-encoded signaling states. |

`utmi_suspendm` is generated by top-level clock, reset, and wake-up logic
rather than being a direct copy of the PIE suspend state. This allows the PHY
to remain active while clock shutdown or wake-up handling is still in
progress.

#### Vendor-Specific UTMI Register Access

| Signal | Direction | Width | Active Level or Encoding | Description |
|---|---:|---:|---|---|
| `utmi_vcontrol[3:0]` | Output | 4 | Encoded | Carries bits `[3:0]` of the software-programmed PHY address during a vendor-specific UTMI access. |
| `utmi_vcontrolloadm` | Output | 1 | Active low | Initiates or loads a vendor-specific PHY control operation. |
| `utmi_vstatus[7:0]` | Input | 8 | Encoded | Vendor-specific PHY status or read-data input returned to the software-visible PHY access path. |

When no vendor-specific access is active, `utmi_vcontrol[3:0]` is zero and
`utmi_vcontrolloadm` remains deasserted high.

---

### ULPI PHY Interface

The ULPI interface connects the shared USB PIE to an external USB 2.0 ULPI
PHY.

The top level exposes separate receive-data, transmit-data, and
transmit-enable signals. When connected to a conventional bidirectional ULPI
data bus, the integration wrapper must implement the required I/O direction
control.

| Signal | Direction | Width | Active Level or Encoding | Description |
|---|---:|---:|---|---|
| `ulpi_clk` | Input | 1 | Rising edge | Clock supplied by the ULPI PHY. It becomes `pie_clk` when ULPI mode is selected. |
| `ulpi_rxdata[7:0]` | Input | 8 | Encoded | Data received from the ULPI PHY. Depending on the operating state, it carries USB packet data, RX commands, PHY-register read data, or low-power indications. |
| `ulpi_txdata[7:0]` | Output | 8 | Encoded | Data transmitted toward the ULPI PHY, including USB packet data, transmit commands, and PHY-register commands. |
| `ulpi_txenable` | Output | 1 | Active high | Enables JANUS to drive the external ULPI data bus. |
| `ulpi_dir` | Input | 1 | Encoded | Indicates the current bus direction. Low allows JANUS to drive the data bus; high indicates that the PHY is driving the bus. |
| `ulpi_stp` | Output | 1 | Active high | ULPI stop and control output. |
| `ulpi_nxt` | Input | 1 | Active high | ULPI handshake input used to qualify transmitted or received information. |
| `ulpi_ddr_sel` | Input | 1 | Encoded | Selects the low-power indication mapping on `ulpi_rxdata[7:0]`. It does not select the normal ULPI packet-transfer mode. |

During ULPI low-power operation, asynchronous line-state and wake-up
information is interpreted according to the following mapping:

| `ulpi_ddr_sel` | Line-State Bits | Wake-Up Interrupt Bit |
|---:|---|---:|
| `0` | `ulpi_rxdata[1:0]` | `ulpi_rxdata[3]` |
| `1` | `ulpi_rxdata[5:4]` | `ulpi_rxdata[7]` |

These asynchronous values are accepted only after `ulpi_dir` has remained
high through the internal synchronization stages and the USB clock has been
detected as stopped.

> **Verification note:** The ULPI path is structurally implemented by the
> RTL. Supported and validated configurations should be documented
> separately from this interface definition.

---

## Host-Control AHB Interfaces

JANUS exposes three independent AHB register-control ports:

- one for the embedded Hub;
- one for DEV0;
- one for DEV1.

All three ports use separate instances of the common `usb_ahb_slave`
front-end.

### Common Register-Control AHB Behavior

The three register-control interfaces have the following behavior:

- 32-bit write and read data;
- four-bit word address corresponding directly to `HADDR[5:2]`;
- 16 addressable register words over a 64-byte window;
- an active transfer is recognized when `HTRANS[1]` is high;
- no inserted wait states;
- `HREADYOUT` permanently asserted;
- `HRESP[1:0]` permanently returns `OKAY`.

Unsupported or unimplemented register addresses return zero or the
block-specific default value and do not generate an AHB error response.

### Hub Control AHB Slave Interface

The Hub Control interface allows an external system master to access the Hub
Control Register.

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `hub_ahbs_haddr[5:2]` | Input | 4 | Word-aligned Hub register address. |
| `hub_ahbs_htrans[1:0]` | Input | 2 | AHB transfer type. Bit 1 identifies an active `NONSEQ` or `SEQ` transfer. |
| `hub_ahbs_hwrite` | Input | 1 | Transfer direction: high for write and low for read. |
| `hub_ahbs_hwdata[31:0]` | Input | 32 | AHB write-data bus. |
| `hub_ahbs_hsel` | Input | 1 | Hub Control AHB slave-select input. |
| `hub_ahbs_hreadyin` | Input | 1 | AHB transfer-ready input used to qualify an active transfer. |
| `hub_ahbs_hrdata[31:0]` | Output | 32 | AHB read-data bus. |
| `hub_ahbs_hreadyout` | Output | 1 | AHB slave-ready output. Permanently asserted. |
| `hub_ahbs_hresp[1:0]` | Output | 2 | AHB transfer response. Permanently returns `OKAY`. |

The Hub register definition is described separately in the Programming Model
section.

### Software-Device Control AHB Slave Interfaces

DEV0 and DEV1 provide structurally equivalent AHB interfaces for accessing
their independent control and status registers.

| DEV0 Signal | DEV1 Signal | Direction | Width | Description |
|---|---|---:|---:|---|
| `dev0_ahbs_haddr[5:2]` | `dev1_ahbs_haddr[5:2]` | Input | 4 | Word-aligned register address. |
| `dev0_ahbs_htrans[1:0]` | `dev1_ahbs_htrans[1:0]` | Input | 2 | AHB transfer type. Bit 1 identifies an active `NONSEQ` or `SEQ` transfer. |
| `dev0_ahbs_hwrite` | `dev1_ahbs_hwrite` | Input | 1 | Transfer direction: high for write and low for read. |
| `dev0_ahbs_hwdata[31:0]` | `dev1_ahbs_hwdata[31:0]` | Input | 32 | AHB write-data bus. |
| `dev0_ahbs_hsel` | `dev1_ahbs_hsel` | Input | 1 | Slave-select input for the corresponding device register interface. |
| `dev0_ahbs_hreadyin` | `dev1_ahbs_hreadyin` | Input | 1 | AHB transfer-ready input used to qualify an active transfer. |
| `dev0_ahbs_hrdata[31:0]` | `dev1_ahbs_hrdata[31:0]` | Output | 32 | AHB read-data bus from the corresponding device register interface. |
| `dev0_ahbs_hreadyout` | `dev1_ahbs_hreadyout` | Output | 1 | AHB slave-ready output. Permanently asserted. |
| `dev0_ahbs_hresp[1:0]` | `dev1_ahbs_hresp[1:0]` | Output | 2 | AHB response. Permanently returns `OKAY`. |

DEV0 and DEV1 maintain independent register state. Their register
definitions are described separately in the Programming Model section.

---

## External Memory Interfaces

JANUS uses three external memories:

- one Hub Descriptor RAM;
- one DEV0 Endpoint RAM;
- one DEV1 Endpoint RAM.

Each memory has:

- an AHB slave interface for external system access;
- a native RAM interface connected to the physical memory;
- an internal USB-side requester.

The internal USB requester and the external AHB interface share the physical
memory port.

### Common RAM AHB Behavior

All three external RAM interfaces use separate instances of
`ahb_dma_slave`.

The common behavior is:

- byte-addressed AHB transfers;
- byte, half-word, and word access support;
- `HSIZE[1:0]` interpreted by the current RTL;
- `HSIZE[2]` not used by the implemented size decoder;
- `HBURST[2:0]` exposed at the boundary but not used by the current RTL;
- internal USB access given priority over external AHB access;
- `HREADYOUT` deasserted when the physical RAM port is unavailable;
- `HRESP[1:0]` permanently set to `OKAY`.

For DEV0 and DEV1, the internal requester is the shared Endpoint Data
Manager. For the Hub Descriptor RAM, the internal requester is the read-only
Hub EP0 path.

The `_dma_` substring in the top-level signal names is inherited from the
legacy internal module name. These ports remain AHB slave interfaces.

### Hub Descriptor RAM AHB Slave Interface

This interface allows an external system master to initialize, read, and
update the memory used by the Hub EP0 control path.

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `hub_desc_ahbs_dma_haddr[RAM_ADDRWIDTH+4:0]` | Input | `RAM_ADDRWIDTH + 5` | Byte-addressed AHB address used by the memory adapter. |
| `hub_desc_ahbs_dma_htrans[1:0]` | Input | 2 | AHB transfer type. Bit 1 identifies an active `NONSEQ` or `SEQ` transfer. |
| `hub_desc_ahbs_dma_hwrite` | Input | 1 | Transfer direction: high for write and low for read. |
| `hub_desc_ahbs_dma_hwdata[AHB_DATAWIDTH-1:0]` | Input | `AHB_DATAWIDTH` | AHB write-data bus. |
| `hub_desc_ahbs_dma_hsel` | Input | 1 | Hub Descriptor RAM AHB slave-select input. |
| `hub_desc_ahbs_dma_hreadyin` | Input | 1 | AHB transfer-ready input used to qualify a new transfer. |
| `hub_desc_ahbs_dma_hrdata[AHB_DATAWIDTH-1:0]` | Output | `AHB_DATAWIDTH` | AHB read-data bus. |
| `hub_desc_ahbs_dma_hreadyout` | Output | 1 | AHB ready output. It may be deasserted while the RAM is owned by the Hub EP0 path. |
| `hub_desc_ahbs_dma_hresp[1:0]` | Output | 2 | AHB transfer response. Permanently returns `OKAY`. |
| `hub_desc_ahbs_dma_hsize[2:0]` | Input | 3 | AHB transfer size. Byte, half-word, and word accesses are supported through `HSIZE[1:0]`. |
| `hub_desc_ahbs_dma_hburst[2:0]` | Input | 3 | AHB burst type. Exposed at the boundary but not used by the current RTL. |

The internal Hub EP0 requester accesses the Hub Descriptor RAM in read-only
mode.

### Software-Device Endpoint RAM AHB Slave Interfaces

DEV0 and DEV1 provide independent and structurally equivalent AHB ports for
external access to their Endpoint RAMs.

| DEV0 Signal | DEV1 Signal | Direction | Width | Description |
|---|---|---:|---:|---|
| `dev0_ahbs_dma_haddr[RAM_ADDRWIDTH+4:0]` | `dev1_ahbs_dma_haddr[RAM_ADDRWIDTH+4:0]` | Input | `RAM_ADDRWIDTH + 5` | Byte-addressed AHB address used by the memory adapter. |
| `dev0_ahbs_dma_htrans[1:0]` | `dev1_ahbs_dma_htrans[1:0]` | Input | 2 | AHB transfer type. Bit 1 identifies an active `NONSEQ` or `SEQ` transfer. |
| `dev0_ahbs_dma_hwrite` | `dev1_ahbs_dma_hwrite` | Input | 1 | Transfer direction: high for write and low for read. |
| `dev0_ahbs_dma_hwdata[AHB_DATAWIDTH-1:0]` | `dev1_ahbs_dma_hwdata[AHB_DATAWIDTH-1:0]` | Input | `AHB_DATAWIDTH` | AHB write-data bus. |
| `dev0_ahbs_dma_hsel` | `dev1_ahbs_dma_hsel` | Input | 1 | AHB slave-select input for the corresponding Endpoint RAM. |
| `dev0_ahbs_dma_hreadyin` | `dev1_ahbs_dma_hreadyin` | Input | 1 | AHB transfer-ready input used to qualify a new transfer. |
| `dev0_ahbs_dma_hrdata[AHB_DATAWIDTH-1:0]` | `dev1_ahbs_dma_hrdata[AHB_DATAWIDTH-1:0]` | Output | `AHB_DATAWIDTH` | AHB read-data bus. |
| `dev0_ahbs_dma_hreadyout` | `dev1_ahbs_dma_hreadyout` | Output | 1 | AHB ready output. It may be deasserted while the internal Endpoint Data Manager owns the RAM. |
| `dev0_ahbs_dma_hresp[1:0]` | `dev1_ahbs_dma_hresp[1:0]` | Output | 2 | AHB transfer response. Permanently returns `OKAY`. |
| `dev0_ahbs_dma_hsize[2:0]` | `dev1_ahbs_dma_hsize[2:0]` | Input | 3 | AHB transfer size. Byte, half-word, and word accesses are supported through `HSIZE[1:0]`. |
| `dev0_ahbs_dma_hburst[2:0]` | `dev1_ahbs_dma_hburst[2:0]` | Input | 3 | AHB burst type. Exposed at the boundary but not used by the current RTL. |

---

### Common Native RAM Behavior

The three native RAM interfaces share the following conventions:

- synchronous operation relative to `hclk`;
- active-high chip select;
- active-low write enable;
- word-addressed native address;
- active-high write-selection mask;
- chip select retained as required by the adapter read-data timing.

Internal USB memory requests have priority over external AHB requests.

### Hub Descriptor RAM Native Interface

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `hub_desc_mem_q[RAM_DATAWIDTH-1:0]` | Input | `RAM_DATAWIDTH` | Read-data bus from the Hub Descriptor RAM. |
| `hub_desc_mem_d[RAM_DATAWIDTH-1:0]` | Output | `RAM_DATAWIDTH` | Write-data bus to the Hub Descriptor RAM. Hub EP0 requests are read-only, so writes originate from the external AHB interface. |
| `hub_desc_mem_cs` | Output | 1 | Active-high RAM chip select. |
| `hub_desc_mem_a[RAM_ADDRWIDTH-1:0]` | Output | `RAM_ADDRWIDTH` | Native RAM word address. |
| `hub_desc_mem_web_out` | Output | 1 | Active-low write enable. Low identifies a write; high identifies a read. |
| `hub_desc_mem_bsel[RAM_DATAWIDTH-1:0]` | Output | `RAM_DATAWIDTH` | Active-high write-selection mask derived from the access size and address. |

### Software-Device Endpoint RAM Native Interfaces

DEV0 and DEV1 use independent native memory ports.

| DEV0 Signal | DEV1 Signal | Direction | Width | Description |
|---|---|---:|---:|---|
| `dev0_mem_q[RAM_DATAWIDTH-1:0]` | `dev1_mem_q[RAM_DATAWIDTH-1:0]` | Input | `RAM_DATAWIDTH` | Read-data bus from the corresponding Endpoint RAM. |
| `dev0_mem_d[RAM_DATAWIDTH-1:0]` | `dev1_mem_d[RAM_DATAWIDTH-1:0]` | Output | `RAM_DATAWIDTH` | Write-data bus to the corresponding Endpoint RAM. |
| `dev0_mem_cs` | `dev1_mem_cs` | Output | 1 | Active-high RAM chip select. |
| `dev0_mem_a[RAM_ADDRWIDTH-1:0]` | `dev1_mem_a[RAM_ADDRWIDTH-1:0]` | Output | `RAM_ADDRWIDTH` | Native RAM word address. |
| `dev0_mem_web_out` | `dev1_mem_web_out` | Output | 1 | Active-low write enable. Low identifies a write; high identifies a read. |
| `dev0_mem_bsel[RAM_DATAWIDTH-1:0]` | `dev1_mem_bsel[RAM_DATAWIDTH-1:0]` | Output | `RAM_DATAWIDTH` | Active-high write-selection mask identifying the affected part of the RAM word. |

With the default configuration, each native RAM interface provides:

- 64-bit read and write data;
- a 15-bit native word address;
- a 64-bit write-selection mask;
- an individually addressable capacity of 256 KiB.

---

## Interrupt and Observation Interfaces

### Software-Device Interrupt Interfaces

DEV0 and DEV1 independently generate one standard interrupt request and one
fast interrupt request.

Each device can report:

- frame events;
- device-level events;
- endpoint events.

Each event source has independent status, enable, and routing control. A
routing value of zero selects IRQ; a routing value of one selects FIQ.

The outputs are active-high and level-sensitive. An output remains asserted
while at least one enabled and pending event is routed to that output.

| DEV0 Signal | DEV1 Signal | Direction | Width | Description |
|---|---|---:|---:|---|
| `dev0_usb_irq` | `dev1_usb_irq` | Output | 1 | Active-high standard interrupt request. |
| `dev0_usb_fiq` | `dev1_usb_fiq` | Output | 1 | Active-high fast interrupt request. |

DEV0 and DEV1 maintain independent interrupt status, enable, and routing
state.

---

### USB Frame Timing Output

`USB_FrameToggle` toggles once per USB frame in Full-Speed mode and once per
microframe in High-Speed mode:

- Full-Speed: one transition every 1 ms;
- High-Speed: one transition every 125 us.

Because the output toggles rather than pulses, its complete waveform
frequency is:

- 500 Hz in Full-Speed mode;
- 4 kHz in High-Speed mode.

| Signal | Direction | Width | Description |
|---|---:|---:|---|
| `USB_FrameToggle` | Output | 1 | Frame or microframe timing toggle generated by the shared USB PIE. Its transition interval depends on the current USB speed. |

> **Debug note:** The internal timer can continue to generate transitions in
> the absence of a valid SOF. Valid SOF reception realigns the timer near the
> expected interval boundary.

`USB_FrameToggle` must not be interpreted as a fixed 1 kHz clock.

---

### USB DMA Write-Access Observation Interface

These outputs expose the write qualification and selected DWORD lanes of the
shared internal USB DMA access before the request is routed toward the Hub,
DEV0, or DEV1 resource.

The outputs do not identify the selected USB function, target resource,
address, write data, or transfer completion.

| Signal | Direction | Width | Active Level | Description |
|---|---:|---:|---|---|
| `usb_dma_dword_selection[1:0]` | Output | 2 | Active high | Identifies the selected 32-bit portions of the internal RAM word. With the default 64-bit RAM, bit 0 selects bits `[31:0]` and bit 1 selects bits `[63:32]`. |
| `usb_dma_write_access` | Output | 1 | Active high | Indicates an active write request from the shared Endpoint Data Manager. |

---

## Static Configuration and Test Interfaces

### Hub and Device Configuration Interface

| Signal | Direction | Width | Active Level | Description |
|---|---:|---:|---|---|
| `USB_EnableHub` | Input | 1 | Active high | Enables the externally controlled Hub operating mode. After two-stage synchronization in the `hclk` domain, the signal is ORed with the software-controlled Hub-enable register. |
| `USB_self_powered` | Input | 1 | Active high | Defines the Self Powered status returned in bit 0 of the Hub standard Device `GET_STATUS` response. High reports self-powered operation; low reports bus-powered operation. |

`USB_self_powered` is consumed by the Hub EP0 Request Handler when generating
the standard Device `GET_STATUS` response. It should be treated as a static
integration input or held stable while the request is processed.

---

### Testability Interface

| Signal | Direction | Width | Active Level | Description |
|---|---:|---:|---|---|
| `async_disable` | Input | 1 | Active high | DFT control that modifies selected asynchronous reset and wake-up paths. It must remain low during normal functional operation. |
| `testmode` | Input | 1 | Active high | Selects test-mode PIE clock behavior. Clock selection is based on the enabled PHY-support generics rather than the runtime PHY mode. |
| `tcb_clkgate_se` | Input | 1 | Active high | Test-infrastructure clock-gating placeholder. The signal is exposed at the top-level boundary but is not consumed by the current RTL. |

When `testmode` is high:

- `utmi_clk` is selected if `C_UTMI_SUPPORT` is `TRUE`;
- otherwise, `ulpi_clk` is selected if `C_ULPI_SUPPORT` is `TRUE`.

UTMI has priority when both PHY interfaces are enabled.

`async_disable` affects selected reset and low-power control paths and should
be driven only by the intended DFT infrastructure.

`tcb_clkgate_se` may be tied to its inactive value in the current
implementation.

---

## Integration Requirements and Constraints

The following requirements apply at the JANUS top-level boundary:

- `hresetn` and `ahbs_resetn` control different portions of the IP and must
  both be provided by the integration environment.
- Both resets are used asynchronously in the `hclk` domain.
- No internal reset-deassertion synchronizer is present for `hresetn` or
  `ahbs_resetn` at the `hclk`-domain boundary.
- Reset deassertion must satisfy the applicable recovery and removal timing
  requirements relative to `hclk`.
- `hresetn` is internally synchronized before entering the `pie_clk` domain.
- `sys_donotwakeup_n` and `sys_dev_wakeup_n` are used directly by the
  top-level power-control logic and are not internally synchronized.
- Asynchronous system-control inputs require appropriate integration-level
  CDC handling or timing qualification.
- `USB_self_powered` should normally be treated as a static configuration
  input.
- UTMI and ULPI are alternative PHY interfaces and require consistent PHY
  mode and clock selection.
- Native RAM chip selects are active high.
- Native RAM write enables are active low.
- Internal USB memory requests have priority over external AHB accesses.
- RAM AHB interfaces may introduce wait states through `HREADYOUT`.
- RAM AHB `HBURST[2:0]` inputs are not used by the current RTL.
- AHB slave interfaces always return `OKAY`.
- `async_disable` is test-only and must remain low during normal operation.
- `tcb_clkgate_se` is unused by the current RTL.
- Configurations differing from the documented JANUS defaults require
  dedicated elaboration and functional validation.

---

## Complete Top-Level Signal Index

| Signal or Prefix | Category | Interface |
|---|---|---|
| `hclk`, `hresetn`, `ahbs_resetn` | System integration | Clock and Reset |
| `usb_needclk`, `sys_donotwakeup_n`, `sys_dev_wakeup_n`, `sys_utmi_clkin_lock` | System integration | Clock Request and Wake-Up |
| `USB_VBus`, `vbuscomp_on`, `chrg_vbus`, `dischrg_vbus`, `avalid`, `sessend` | System integration | VBUS and Analog Control |
| `utmi_*` | USB PHY | UTMI |
| `ulpi_*` | USB PHY | ULPI |
| `hub_ahbs_*` | Host control | Hub Control AHB |
| `dev0_ahbs_*`, `dev1_ahbs_*` | Host control | Software-Device Control AHB |
| `hub_desc_ahbs_dma_*` | External memory access | Hub Descriptor RAM AHB |
| `dev0_ahbs_dma_*`, `dev1_ahbs_dma_*` | External memory access | Endpoint RAM AHB |
| `hub_desc_mem_*` | Native memory | Hub Descriptor RAM |
| `dev0_mem_*`, `dev1_mem_*` | Native memory | Endpoint RAM |
| `dev0_usb_irq`, `dev0_usb_fiq`, `dev1_usb_irq`, `dev1_usb_fiq` | Interrupt | Software-Device Interrupts |
| `USB_FrameToggle` | Observation | Frame Timing |
| `usb_dma_dword_selection`, `usb_dma_write_access` | Observation | USB DMA Write Access |
| `USB_EnableHub`, `USB_self_powered` | Static configuration | Hub and Device Configuration |
| `async_disable`, `testmode`, `tcb_clkgate_se` | Test | Testability |

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


# Operational Flows

The previous sections describe the JANUS architecture from a structural
perspective: RTL blocks, clock domains, functional interfaces, endpoint
contexts, external memories, and top-level routing.

This final section describes how those elements cooperate during
representative USB transactions.

The objective is not limited to reproducing the protocol sequence observed
by the USB host. Each flow also identifies:

- the block that recognizes and initiates each operation;
- the function-selection and endpoint-context lookup sequence;
- the control and payload paths used by the transaction;
- the location in which request, context, and payload information is stored;
- the block responsible for request-specific processing;
- the mechanism used to prepare the next USB transfer stage;
- the endpoint-state updates performed after transaction completion;
- the principal RTL signals and states useful during simulation debug.

These flows are intended to support:

- architectural understanding;
- RTL navigation;
- directed verification development;
- waveform analysis and debug;
- integration of the external RAMs and AHB control paths;
- future modification or extension of the IP.

## Common Transaction Model

All USB transactions enter JANUS through the shared USB Protocol and
Interface Engine.

At a high level, each transaction follows this sequence:

```text
USB token and packet reception
  -> function address matching
  -> selected-function identification
  -> endpoint-context lookup
  -> function-specific context or memory access
  -> payload transfer or request processing
  -> USB response generation
  -> endpoint runtime-state update
```

The PIE receives the effective enable, current address, and temporary address
of all three USB functions:

```text
Function 0: Embedded Hub
Function 1: DEV0
Function 2: DEV1
```

After accepting a token, the PIE generates `pie_dev_selected` to identify the
target function.

The selected-function indication crosses `usb_synchronizer_1` and becomes
`sync_pie_dev_selected` in the `hclk` domain.

Top-level selected-function logic then controls:

- Hub versus software-device access selection;
- DEV0 versus DEV1 Endpoint RAM selection;
- the function context presented to `usb_dma_1`;
- SETUP-event routing;
- DMA endpoint-state update routing;
- grant and read-data response selection.

The PIE and Endpoint Data Manager use a common transaction and endpoint
interface for all three USB functions. The implementation behind that
interface is function-dependent.

```text
Embedded Hub

Endpoint runtime context:
  usb_ep_config_handler_1

EP0 SETUP storage and request decode:
  hub_ep0_handler_1

Hub and port class behavior:
  usb_app_hw_hub_1

Descriptors, decode tables, and stored responses:
  Hub Descriptor RAM

Hub Status Change EP1 IN payload:
  usb_app_hw_hub_1
```

```text
DEV0 and DEV1

Device control and compact endpoint state:
  usb_reg_if_1 / usb_reg_if_2

Detailed endpoint context:
  DEV0 / DEV1 Endpoint RAM

SETUP, TX, and RX payload storage:
  DEV0 / DEV1 Endpoint RAM

Control-request interpretation and response preparation:
  External software or control agent through AHB
```

The operational descriptions therefore distinguish between:

- processing common to all USB functions;
- hardware-managed Hub operations;
- software-managed DEV0 and DEV1 operations;
- endpoint-context reads and runtime-state updates;
- control paths and payload paths.

## Flow Description Convention

Each operational flow follows this sequence whenever applicable:

```text
1. USB request acceptance
2. Function and endpoint selection
3. Endpoint-context lookup
4. Request or payload transfer
5. Function-specific processing
6. Preparation of the next USB stage
7. USB response or data transfer
8. Completion and runtime-state update
```

Signal names refer to the RTL names described in the architecture and
functional-interface sections.

Some top-level glue logic is represented functionally:

- SETUP-event routing may be shown as a direct function-specific notification
  even when the RTL uses an intermediate pending flag;
- Hub connection may be shown as a functional PIE input even though it
  contributes to both the function-enable vector and the synchronized
  upstream-connect path;
- selected-function context and RAM routing may be described as one
  architectural operation even when several combinational assignments and
  muxes implement the path.

These simplifications preserve the implemented behavior while avoiding
unnecessary repetition of intermediate top-level nets.

## Covered Operational Flows

The representative flows described below are:

1. the common Hub EP0 SETUP reception and decoding flow;
2. a standard control request to Hub EP0;
3. a descriptor request to Hub EP0;
4. a Hub Class request to Hub EP0;
5. a Hub Status Change Interrupt IN transfer on Hub EP1;
6. a control transfer to DEV0 or DEV1;
7. a Bulk IN transfer to DEV0 or DEV1;
8. a Bulk OUT transfer to DEV0 or DEV1.

---

# Common Hub EP0 SETUP Reception and Decode

The embedded Hub implements EP0 entirely in hardware.

All Hub standard, descriptor, and Hub Class requests initially use the same
SETUP reception and decoding sequence.

The flow is divided into four phases:

```text
1. Hub EP0 context lookup
2. Eight-byte SETUP packet reception and storage
3. Autonomous Setup Decode Table lookup
4. EP0 request and transfer-context preparation
```

The main blocks involved are:

```text
usb_pie_1
  USB token, packet, and handshake processing

usb_dma_1
  EP0 context lookup and SETUP payload transfer

hub_ep0_handler_1
  SETUP storage and request decoding

usb_ep_config_handler_1
  Hub EP0 runtime-context storage

hub_desc_ahb_dma_slave
  Hub Descriptor RAM access arbitration and adaptation

Hub Descriptor RAM
  Device link and Setup Decode Table storage
```

## Hub EP0 Context Lookup

When the host sends a SETUP token to the current or temporary Hub address:

1. `usb_pie_1` decodes the token address and endpoint number.
2. The PIE compares the token address with the current and temporary address
   of every enabled USB function.
3. The Hub is selected as function index `0`.
4. The PIE identifies endpoint `0` and a SETUP transaction.
5. The PIE generates the endpoint-context request:

```text
pie_epinfo_req
pie_epinfo_epnr[3:0] = 0
pie_epinfo_epdir
pie_epinfo_setup = 1
pie_dev_selected = 0
```

6. The endpoint request and selected-function index cross
   `usb_synchronizer_1`.
7. Top-level selected-function logic supplies the predefined Hub context
   mapping to `usb_dma_1`.
8. `usb_dma_1` generates a context read through Hub address region `11`.
9. The Hub Function Resource Decoder routes the request to
   `usb_ep_config_handler_1`.
10. `usb_ep_config_handler_1` returns the encoded Hub EP0 OUT context.
11. `usb_dma_1` decodes the returned context.
12. The corresponding `epinfo_*` information crosses back to the PIE.

The returned information includes:

```text
Endpoint valid
Endpoint active
Endpoint disabled
Endpoint STALL state
Endpoint toggle
Transfer byte count
Maximum-packet information
Endpoint attributes
```

The PIE uses this context to determine whether the SETUP transaction can be
accepted.

## SETUP Packet Reception

After the SETUP token is accepted, the host transmits the eight-byte SETUP
data packet.

The payload path is:

```text
USB Host
  -> USB PHY
  -> usb_pie_1
  -> usb_synchronizer_1
  -> usb_dma_1
  -> usb_fs_mux_1
  -> Hub Function Resource Decoder
  -> hub_ep0_handler_1
```

The sequence is:

1. `usb_pie_1` receives the DATA0 packet.
2. The PIE validates the packet PID, length, and CRC.
3. The payload, byte count, and receive-valid information cross
   `usb_synchronizer_1`.
4. `usb_dma_1` recognizes the transaction as SETUP through:

```text
sync_sieint_epinfo_setup = 1
```

5. The Endpoint Data Manager applies SETUP-specific handling:
   - the transfer size is forced to eight bytes;
   - the SETUP storage location is selected;
   - the transaction is distinguished from a normal EP0 OUT transaction.
6. `usb_dma_1` generates a write through the Shared Endpoint Access
   interface.
7. `usb_fs_mux_1` selects the Hub function path.
8. The Hub Function Resource Decoder selects address region `00`.
9. The request is presented to `hub_ep0_handler_1`.
10. `upd_dma_addr[14]` qualifies the internal SETUP storage area.

## SETUP Packet Storage

`hub_ep0_handler_1` stores the received packet in:

```text
setup_bytes[63:0]
```

The SETUP packet is stored inside the EP0 handler.

It is not stored in the Hub Descriptor RAM.

The operation can be summarized as:

```text
usb_dma_1
  -> upd_dma_req_ep0
  -> upd_dma_write
  -> upd_dma_wdata
  -> setup_bytes[63:0]
```

For a 64-bit internal data path, the complete SETUP packet can be written in
one transfer.

For a 32-bit internal data path, the packet is written as two 32-bit words.

After the packet has been accepted and validated, the PIE transmits the USB
ACK and generates:

```text
pie_epinfo_setup_received
```

The event crosses into the `hclk` domain as:

```text
sync_sieint_setup_received
```

## Hub SETUP Decode Activation

In the implemented RTL, `sync_sieint_setup_received` does not directly drive
the Setup Decode FSM.

Top-level logic converts the single-cycle event into the persistent pending
indication:

```text
usbreg_setup_to_decode[0]
```

The request-completion mechanism is:

```text
SETUP packet received
  -> usbreg_setup_to_decode[0] set

SETUP decode completed
  -> ep0_setupdone[0] asserted
  -> usbreg_setup_to_decode[0] cleared
```

The index `[0]` identifies the only hardware-controlled USB function in the
current integration, the embedded Hub.

The architecture diagram may intentionally represent this mechanism as:

```text
SETUP received
  -> Hub EP0 Request Handler
```

This representation is a functional simplification. The RTL implements a
pending flag and completion acknowledgement around the EP0 handler.

When `hub_ep0_handler_1` is idle and observes:

```text
usbreg_setup_to_decode[0] = 1
```

the handler begins the autonomous Hub Setup Decode Table lookup.

## Autonomous Hub Descriptor RAM Access

During SETUP decoding, `hub_ep0_handler_1` becomes the active internal
requester of the Hub Descriptor RAM.

The interface is:

```text
ep0_mem_req
ep0_mem_addr[11:0]
ep0_mem_gnt
ep0_mem_rdata[RAM_DATAWIDTH-1:0]
```

The path is:

```text
hub_ep0_handler_1
  -> ep0_mem_*
  -> hub_desc_ahb_dma_slave
  -> Hub Descriptor RAM
```

The handler's access is read-only.

`hub_desc_ahb_dma_slave` gives the internal EP0 request priority over an
external AHB request to the same RAM.

The Setup Decode FSM uses the following main states:

```text
IDLE
READ_DEV_LINK
READ_SETUP_LSB
READ_SETUP_MASK_LSB
READ_SETUP_MSB
READ_SETUP_MASK_MSB
SETUP_DONE
```

## Device-Link Lookup

The first RAM lookup is performed in:

```text
READ_DEV_LINK
```

The handler reads the device-link entry associated with the selected
hardware-controlled function:

```text
C_DEV_LINK_START + device index
```

In the current integration:

```text
device index = 0
```

The returned word contains a reference to the first entry in the Hub Setup
Decode Table.

The handler obtains the next address from:

```text
ep0_mem_rdata[11:0]
```

and proceeds to the first Setup Decode Table entry.

The start address of the decode table is therefore defined by the Descriptor
RAM contents rather than being hardcoded in the EP0 handler.

## Lower SETUP Comparison

In:

```text
READ_SETUP_LSB
```

the handler reads the first comparison word of the current table entry.

The handler:

1. stores the comparison value;
2. compares the lower portion of the received SETUP packet with the table
   pattern;
3. retains the partial match result;
4. advances to `READ_SETUP_MASK_LSB`.

In:

```text
READ_SETUP_MASK_LSB
```

the handler reads the associated mask and request metadata.

Conceptually, the comparison is:

```text
received SETUP field AND table mask
  compared with
table comparison value
```

The table entry also supplies:

```text
setup_request[6:0]
setup_last
setup_data_buffer[7:0]
```

- `setup_request[6:0]` identifies the internal operation represented by the
  entry.
- `setup_last` identifies the final entry in the current decode list.
- `setup_data_buffer[7:0]` identifies the response or data-buffer reference.

If the lower comparisons succeed, the FSM continues with the upper part of
the SETUP packet.

If the comparison fails:

- the handler advances to the next table entry when `setup_last = 0`;
- the handler terminates the lookup with no valid request when
  `setup_last = 1`.

The next-entry operation updates the RAM address according to the table-entry
layout and restarts the comparison sequence.

## Upper SETUP Comparison

In:

```text
READ_SETUP_MSB
```

the handler reads the upper comparison information.

This phase also determines the effective response length.

If the table entry specifies a response length smaller than the `wLength`
received from the host, the smaller value is selected.

Conceptually:

```text
effective response length =
  minimum(received wLength, table-defined maximum response length)
```

The selected length is retained for the subsequent EP0 context generation.

The FSM then enters:

```text
READ_SETUP_MASK_MSB
```

where the upper SETUP fields are compared using the table-defined mask.

If the lower and upper comparisons both succeed, the request is considered
decoded.

The handler then:

```text
retains setup_request[6:0]
retains setup_data_buffer[7:0]
prepares the transfer direction
prepares the transfer byte count
asserts ep0_in_active when required
asserts ep0_out_active when required
asserts ep0_setupdone[0]
```

If the upper comparison fails:

- the handler advances to the next entry when another entry is available;
- the handler clears the request code and completes the lookup when the
  current entry is the last entry.

The FSM enters `SETUP_DONE` and then returns to `IDLE`.

## Decode Result

A successful lookup produces two groups of information.

### Request-Semantic Information

```text
setup_request[6:0]
ep0_wvalue[15:0]
ep0_windex[15:0]
```

These values identify:

- the internal request to be executed;
- the original SETUP `wValue`;
- the original SETUP `wIndex`.

They are consumed by:

- the standard-request logic inside `hub_ep0_handler_1`;
- `usb_app_hw_hub_1` for Hub and Port class requests.

### EP0 Transfer-Context Information

```text
ep0_setupdone[0]
ep0_out_active
ep0_in_active
ep0_outin_nbytes[C_EPNBYTEWIDTH-1:0]
ep0_setup_dir
ep0_data_buffer[7:0]
```

These signals define the EP0 state required for the subsequent DATA or
STATUS stage.

When `ep0_setupdone[0]` is asserted,
`usb_ep_config_handler_1` captures the prepared information into its Hub EP0
runtime-context registers.

The Endpoint Data Manager does not receive `ep0_setupdone[0]` directly.

SETUP decode completion therefore does not cause `usb_dma_1` to start the
next transfer.

The next operation begins only when the host sends the next USB token and the
PIE requests the updated EP0 context.

## Hub EP0 Response-Source Selection

During a subsequent DMA-initiated EP0 response read,
`upd_dma_addr[13:12]` selects one of three mutually exclusive response
sources:

```text
00:
  Standard-request response generated by hub_ep0_handler_1

01:
  Hub Class response generated by usb_app_hw_hub_1

1x:
  Descriptor or stored response read from the Hub Descriptor RAM
```

The EP0 handler therefore performs two distinct roles:

```text
During SETUP decoding:
  Active requester of the Hub Descriptor RAM

During an EP0 IN data stage:
  Passive EP0 response gateway and response-source mux
```

## Primary Debug Observability

The principal signals and states for the common Hub SETUP flow are:

```text
PIE:
  pie_dev_selected
  pie_epinfo_req
  pie_epinfo_epnr
  pie_epinfo_epdir
  pie_epinfo_setup
  pie_epinfo_setup_received

Clock-Domain Bridge:
  sync_pie_dev_selected
  sync_sieint_epinfo_req
  sync_sieint_epinfo_setup
  sync_sieint_setup_received

Endpoint Data Manager:
  dma_state
  dma_dma_req
  dma_dma_write
  dma_dma_addr
  dma_dma_wdata
  dma_dma_gnt
  dma_dma_rdata

Hub EP0 Request Handler:
  setup_bytes
  usbreg_setup_to_decode
  ep0_mem_access_state
  setup_decode_state
  ep0_mem_req
  ep0_mem_addr
  ep0_mem_gnt
  ep0_mem_rdata
  setup_request
  setup_data_buffer
  ep0_setupdone
  ep0_in_active
  ep0_out_active
  ep0_outin_nbytes
```

A valid common Hub SETUP flow should show:

```text
Function 0 selected
  -> Hub EP0 OUT context read
  -> eight-byte SETUP packet written
  -> SETUP-received event
  -> decode pending set
  -> device-link read
  -> Setup Decode Table browsing
  -> request match
  -> EP0 context prepared
  -> ep0_setupdone asserted
```

---

# Standard Control Request to Hub EP0

After a successful Setup Decode Table lookup, `hub_ep0_handler_1` evaluates
`setup_request[6:0]`.

Supported standard requests handled by the EP0 handler include:

```text
SET_ADDRESS
SET_CONFIGURATION
GET_CONFIGURATION
GET_INTERFACE
GET_STATUS for Device
GET_STATUS for Interface
GET_STATUS for Endpoint
SET_FEATURE for Device
SET_FEATURE for Endpoint
CLEAR_FEATURE for Device
CLEAR_FEATURE for Endpoint
```

The handler uses the original SETUP fields stored in `setup_bytes[63:0]`
together with current device and endpoint state.

Relevant state sources include:

```text
Current Hub configuration state
Remote-wakeup enable state
Endpoint STALL state from usb_ep_config_handler_1
USB_self_powered
Original wValue and wIndex fields
```

## State-Changing Standard Requests

For state-changing standard requests, the handler generates the corresponding
control effects.

Examples include:

```text
SET_ADDRESS
  -> assert ep0_new_address
  -> provide ep0_address[6:0]

SET_CONFIGURATION
  -> update the Hub configured state
  -> update the corresponding endpoint configuration state

SET_FEATURE(Device)
  -> enable remote wake-up
  -> apply supported test-mode behavior where applicable

CLEAR_FEATURE(Device)
  -> disable remote wake-up

SET_FEATURE(Endpoint)
  -> set endpoint STALL

CLEAR_FEATURE(Endpoint)
  -> clear endpoint STALL
  -> request endpoint toggle reset
```

These effects are generated when SETUP decoding completes.

## Short Standard-Request Response Generation

For a standard request requiring a short IN response, the EP0 handler builds
the complete response internally.

The response is constructed combinationally in:

```text
setup_data[31:0]
```

The response can combine:

- current dynamic state;
- static integration configuration;
- protocol-defined constant values;
- reserved fields hardcoded to zero.

For example:

```text
GET_STATUS(Endpoint)

bit 0:
  Current endpoint STALL state

bits 15:1:
  Zero
```

At SETUP decode completion, the generated value is stored in:

```text
setup_bytes[31:0]
```

The lower portion of the original SETUP storage is therefore reused as the
registered standard-response container.

The stored response is exposed to the Endpoint Data Manager as:

```text
std_req_data[31:0]
```

The value is a snapshot of the state evaluated when the request was decoded.

The response is not reconstructed when `usb_dma_1` later reads it.

Although the response container is 32 bits wide, the currently supported
short standard responses normally contain one or two meaningful bytes.

## Standard Control Read Data Stage

When the host sends the subsequent IN token:

1. The PIE selects the Hub and requests the EP0 IN context.
2. `usb_dma_1` reads the updated context through Hub region `11`.
3. `usb_ep_config_handler_1` returns the registered EP0 IN context.
4. The context identifies:
   - EP0 IN as active;
   - the transfer byte count;
   - the standard-response source.
5. `usb_dma_1` generates a response-data read through Hub region `00`.
6. Inside `hub_ep0_handler_1`, address bits `[13:12] = 00` select:

```text
std_req_data[31:0]
```

7. The response is returned through `upd_dma_rdata_ep0`.
8. The Endpoint Data Manager transfers the response through
   `usb_synchronizer_1`.
9. The PIE transmits the DATA packet.
10. The host returns the handshake.
11. The PIE reports transaction completion and success.
12. `usb_dma_1` updates the Hub EP0 runtime context.

During this data read, `hub_ep0_handler_1` is passive with respect to
transaction initiation.

`usb_dma_1` is the active requester.

## Standard Control Write Without a Data Stage

For requests whose complete meaning is contained in the SETUP packet, no
separate DATA OUT payload is required.

Examples include:

```text
SET_ADDRESS
SET_CONFIGURATION
SET_FEATURE
CLEAR_FEATURE
```

The EP0 handler:

1. decodes the request;
2. applies or initiates the required state update;
3. prepares EP0 IN for a zero-length status stage;
4. transfers the updated EP0 context to
   `usb_ep_config_handler_1`.

When the host sends the status-stage IN token:

1. The PIE requests the updated Hub EP0 IN context.
2. `usb_dma_1` reads the context through Hub region `11`.
3. The context indicates an active zero-length EP0 IN transaction.
4. The PIE transmits the zero-length DATA packet.
5. Transfer completion updates the Hub EP0 runtime state.

The EP0 handler prepares the status-stage context.

The PIE executes the actual USB status-stage transaction.

No supported Hub request requiring a separate DATA OUT payload has been
identified in the current implementation.

## Standard Request Debug Sequence

A valid standard-request flow should show:

```text
Common Hub SETUP flow
  -> standard request identified
  -> current state evaluated
  -> action or short response prepared
  -> ep0_setupdone asserted
  -> EP0 context captured
  -> next host token
  -> standard response or zero-length status transaction
  -> EP0 state updated
```

---

# Descriptor Request to Hub EP0

`GET_DESCRIPTOR` uses the common Hub SETUP reception and decode-table lookup.

The descriptor response is not stored in the 32-bit standard-response
container.

The descriptor is stored in the external Hub Descriptor RAM.

The matching Setup Decode Table entry supplies the response or data-buffer
reference used to locate the descriptor.

After identifying the descriptor request, `hub_ep0_handler_1`:

1. retains the descriptor request code;
2. retains the descriptor data-buffer reference;
3. limits the effective response length using:
   - the received `wLength`;
   - the length defined by the table entry;
4. marks EP0 IN active;
5. supplies the effective transfer byte count;
6. supplies the descriptor data-buffer selection;
7. asserts `ep0_setupdone[0]`.

`usb_ep_config_handler_1` captures the resulting EP0 IN context.

## Descriptor Data Read

When the host sends the first descriptor IN token:

1. The PIE selects the Hub.
2. The PIE requests the Hub EP0 IN context.
3. `usb_dma_1` reads the context through Hub region `11`.
4. The context indicates that the payload resides in the Descriptor RAM or
   stored-response region.
5. `usb_dma_1` generates a payload read through Hub region `00`.
6. Inside `hub_ep0_handler_1`, address bits `[13:12] = 1x` select the
   Descriptor RAM response path.
7. The handler translates the DMA payload address into:

```text
ep0_mem_addr[11:0]
```

8. The handler asserts `ep0_mem_req`.
9. `hub_desc_ahb_dma_slave` grants the internal read access to the physical
   Descriptor RAM port.
10. The Hub Descriptor RAM returns the selected word.
11. The RAM adapter returns the word through `ep0_mem_rdata`.
12. The EP0 handler forwards the word through `upd_dma_rdata_ep0`.
13. `usb_dma_1` selects the required bytes.
14. The data crosses `usb_synchronizer_1`.
15. The PIE transmits the descriptor DATA packet.
16. The host returns the handshake.
17. The PIE reports completion.
18. `usb_dma_1` updates the remaining byte count and payload position.

For a descriptor larger than one maximum-size packet, the endpoint remains
active and the same context and payload-read sequence repeats for each
subsequent IN token.

The operational ownership during the descriptor data stage is:

```text
usb_dma_1
  Initiates each descriptor-data read

hub_ep0_handler_1
  Performs address adaptation, request forwarding,
  and response-source selection

hub_desc_ahb_dma_slave
  Arbitrates the Descriptor RAM port

Hub Descriptor RAM
  Stores the descriptor payload
```

This differs from the SETUP decode phase:

```text
SETUP decode:
  hub_ep0_handler_1 autonomously initiates the RAM reads

Descriptor DATA stage:
  usb_dma_1 initiates the RAM reads
  hub_ep0_handler_1 acts as a passive gateway
```

## Descriptor Status Stage

After the final descriptor DATA packet:

1. The host sends the zero-length OUT status transaction.
2. The PIE requests the Hub EP0 OUT context.
3. `usb_dma_1` returns the prepared endpoint state.
4. The PIE accepts and validates the zero-length OUT packet.
5. Transfer completion updates the Hub EP0 context.
6. The control transfer terminates.

## Primary Debug Observability

The principal signals for a descriptor transfer are:

```text
SETUP decode:
  setup_bytes
  setup_decode_state
  setup_request
  setup_data_buffer
  ep0_outin_nbytes
  ep0_setupdone

Descriptor payload access:
  dma_dma_addr
  dma_dma_req
  upd_dma_addr
  upd_dma_req_ep0
  ep0_mem_access_state
  ep0_mem_req
  ep0_mem_addr
  ep0_mem_gnt
  ep0_mem_rdata
  upd_dma_rdata_ep0

PIE transmit path:
  epinfo_sync_txdata
  epinfo_sync_txdata_valid
  sync_sieint_txdatafetched
  sync_sieint_endtransfer
  sync_sieint_success
```

A valid descriptor flow should show:

```text
Common Hub SETUP flow
  -> descriptor request matched
  -> descriptor buffer selected
  -> EP0 IN context activated
  -> host IN token
  -> DMA context read
  -> DMA-driven Descriptor RAM read
  -> descriptor DATA packet
  -> byte-count and payload-position update
  -> final zero-length OUT status stage
```

---

# Hub Class Request to Hub EP0

Hub and Port class requests use the common Hub SETUP storage and decode-table
lookup flow.

The Setup Decode Table identifies the request as a Hub Class operation and
provides the internal request code.

At decode completion, `hub_ep0_handler_1` exports:

```text
ep0_setupdone
ep0_request[6:0]
ep0_wvalue[15:0]
ep0_windex[15:0]
```

These signals are consumed by `usb_app_hw_hub_1`.

The Hub controller:

1. checks whether `ep0_request[6:0]` identifies a supported Hub or Port class
   request;
2. interprets `ep0_wvalue[15:0]`;
3. selects the target downstream port using `ep0_windex[15:0]`;
4. reads or updates the selected Hub or port state;
5. generates a state change or response as required.

The downstream-port mapping is:

```text
wIndex = 1
  -> Hub Port 1
  -> DEV0

wIndex = 2
  -> Hub Port 2
  -> DEV1
```

## Hub Class State-Changing Requests

Representative state-changing operations include:

```text
SET_FEATURE(PORT_RESET)
  -> assert hub_port_reset for the selected port
  -> set the selected port enable state
  -> update the corresponding reset-change state

CLEAR_FEATURE(PORT_ENABLE)
  -> clear the selected port enable state

CLEAR_FEATURE(C_PORT_CONNECTION)
  -> clear the selected connection-change indication

CLEAR_FEATURE(C_PORT_RESET)
  -> clear the selected reset-change indication
```

The decoded Hub or Port operation is executed by `usb_app_hw_hub_1`, not by
the EP0 handler.

The EP0 handler remains responsible for preparing the control-transfer
context, including the subsequent status stage.

## Hub Class Read Requests

For Hub or Port status reads, `usb_app_hw_hub_1` constructs:

```text
ep0_class_rdata[RAM_DATAWIDTH-1:0]
```

The response is derived from the current Hub and downstream-port state.

When the host sends the subsequent EP0 IN token:

1. The PIE requests the updated Hub EP0 IN context.
2. `usb_dma_1` reads the context through Hub region `11`.
3. The context identifies the Hub Class response source.
4. `usb_dma_1` requests the response through Hub region `00`.
5. Inside `hub_ep0_handler_1`, address bits `[13:12] = 01` select:

```text
ep0_class_rdata
```

6. The EP0 handler forwards the selected response combinationally.
7. `usb_dma_1` transfers the response through the Clock-Domain Bridge.
8. The PIE transmits the Hub EP0 IN DATA packet.
9. The host returns the handshake.
10. Transfer completion updates the Hub EP0 context.

`ep0_class_rdata` is not stored by `hub_ep0_handler_1`.

The Hub controller owns the state from which the response is generated.

The EP0 handler acts as the response-source selector during the DMA read.

The connected implementation supports one response word.
`ep0_class_addr[3:0]` is not connected in the current top-level integration.

## Hub Class Debug Sequence

The principal signals are:

```text
Hub EP0 Request Handler:
  setup_bytes
  setup_request
  ep0_setupdone
  ep0_request
  ep0_wvalue
  ep0_windex
  ep0_data_buffer

Hub Controller:
  ep0_setupdone
  ep0_request
  ep0_wvalue
  ep0_windex
  ep0_class_rdata
  hub_port_connect
  hub_port_enable
  hub_port_reset

Response path:
  upd_dma_req_ep0
  upd_dma_addr[13:12]
  upd_dma_rdata_ep0
```

A valid Hub Class flow should show:

```text
Common Hub SETUP flow
  -> Hub Class request identified
  -> ep0_setupdone
  -> request dispatched to usb_app_hw_hub_1
  -> Hub or port state evaluated or updated
  -> EP0 context activated
  -> Hub Class response or zero-length status stage
```

---

# Hub Status Change EP1 IN Transfer

Hub EP1 IN is an Interrupt IN endpoint.

Hub EP1 does not receive USB control requests.

The host periodically polls the endpoint to determine whether Hub or
downstream-port status has changed.

The report payload is generated directly by `usb_app_hw_hub_1`.

## Status-Change Detection

The Hub controller monitors state associated with the two downstream ports,
including:

```text
Connection state and connection change
Port enable state
Suspend state and suspend change
Reset state and reset change
```

When a reportable condition becomes pending, the Hub controller:

1. updates its internal Hub or port change state;
2. updates the Hub Status Change bitmap;
3. asserts `hub_epin_enable_buffer`;
4. supplies `hub_epin_buffer_size[6:0]`;
5. provides the related EP1 IN control signals to
   `usb_ep_config_handler_1`.

The Context Control interface is:

```text
hub_epin_stall
hub_epin_clear_buffer
hub_epin_enable_buffer
hub_epin_buffer_size[6:0]
```

Top-level logic maps these signals to the single non-control hardware
endpoint entry:

```text
ep_stall[0]
ep_clear_buffer[0]
ep_enable_buffer[0]
ep_buffer_size[6:0]
```

`usb_ep_config_handler_1` consequently records Hub EP1 IN as active when a
status-change report is available.

## Host Poll of Hub EP1 IN

When the host sends an IN token to Hub endpoint 1:

1. The PIE matches the Hub address.
2. The PIE selects function index `0`.
3. The PIE identifies endpoint `1`, direction IN.
4. The PIE generates an endpoint-context request.
5. The request crosses `usb_synchronizer_1`.
6. `usb_dma_1` reads Hub EP1 IN context through Hub region `11`.
7. `usb_ep_config_handler_1` returns:
   - active state;
   - disabled state;
   - STALL state;
   - byte count;
   - toggle-related state;
   - endpoint attributes.
8. `usb_dma_1` returns the decoded context to the PIE.

The PIE selects the USB response according to that context:

```text
Endpoint inactive:
  NAK

Endpoint stalled:
  STALL

Endpoint active:
  Continue with the Interrupt IN DATA transaction
```

## Hub EP1 IN Payload Read

If the endpoint is active:

1. `usb_dma_1` generates a payload read through Hub region `01`.
2. The Hub Function Resource Decoder asserts:

```text
upd_dma_req_ep_hub
```

3. `upd_dma_addr[4:2]` is presented as:

```text
hub_epin_addr[2:0]
```

4. `usb_app_hw_hub_1` returns:

```text
hub_epin_gnt
hub_epin_rdata[RAM_DATAWIDTH-1:0]
```

5. The top-level response is returned as:

```text
upd_dma_gnt_ep_noram
upd_dma_rdata_ep_noram[RAM_DATAWIDTH-1:0]
```

6. `usb_dma_1` selects the required status-change data.
7. The payload crosses `usb_synchronizer_1`.
8. The PIE transmits the Interrupt IN DATA packet.
9. The host acknowledges the packet.
10. The PIE reports transfer completion.
11. `usb_dma_1` updates the Hub EP1 IN context through Hub region `11`.
12. The Hub controller and Context Manager release or rearm the current
    report through the EP1 IN Context Control interface.

This payload path bypasses `hub_ep0_handler_1`.

It does not use a payload RAM.

The two response paths generated by `usb_app_hw_hub_1` are therefore
distinct:

```text
Hub Class response on EP0 IN:
  usb_app_hw_hub_1
  -> ep0_class_rdata
  -> hub_ep0_handler_1
  -> usb_dma_1
  -> usb_pie_1

Hub Status Change report on EP1 IN:
  usb_app_hw_hub_1
  -> hub_epin_rdata
  -> usb_dma_1
  -> usb_pie_1
```

## Primary Debug Observability

The principal signals for Hub EP1 IN are:

```text
Port state:
  hub_port_connect
  hub_port_enable
  hub_port_reset
  hub_port_status_change

EP1 IN Context Control:
  hub_epin_stall
  hub_epin_clear_buffer
  hub_epin_enable_buffer
  hub_epin_buffer_size

Context lookup:
  sync_sieint_epinfo_epnr
  sync_sieint_epinfo_epdir
  upd_dma_req_config
  upd_dma_rdata_config
  epinfo_sync_active
  epinfo_sync_stall
  epinfo_sync_nbytes

Payload access:
  upd_dma_req_ep_hub
  hub_epin_req
  hub_epin_addr
  hub_epin_gnt
  hub_epin_rdata
  upd_dma_gnt_ep_noram
  upd_dma_rdata_ep_noram
```

A valid Hub Status Change flow should show:

```text
Port change detected
  -> Hub status-change bitmap updated
  -> EP1 IN context activated
  -> host polls EP1 IN
  -> context lookup
  -> direct Hub-controller payload read
  -> Interrupt IN DATA packet
  -> report and endpoint context updated
```

---

# Control Transfer to DEV0 or DEV1

DEV0 and DEV1 implement EP0 through software-visible registers and their
respective Endpoint RAMs.

The hardware transfers the SETUP packet into the selected Endpoint RAM and
reports the event through the corresponding `usb_reg_if`.

The SETUP request is interpreted and serviced by software or by an external
control agent through the AHB interfaces.

The following description uses `DEVx` to represent DEV0 or DEV1.

## Initial Device Conditions

After a downstream port reset:

1. `hub_port_reset[0]` or `hub_port_reset[1]` is routed to the corresponding
   software-device reset path.
2. The selected `usb_reg_if` receives the reset event.
3. The current and temporary USB addresses return to zero.
4. Reset status and change information is recorded.
5. EP0 and the Endpoint RAM must contain valid initialization before the
   device can complete enumeration.

The effective enable supplied to the PIE is:

```text
DEVx effective enable =
  DEVx local function enable
  AND
  corresponding Hub port enable
```

The downstream soft-connect state is separate from the local function
enable:

```text
DEV0 soft connect
  -> hub_port_connect[0]

DEV1 soft connect
  -> hub_port_connect[1]
```

Soft connect allows the Hub to report downstream connection before the
software-device function becomes eligible for PIE selection.

## DEVx EP0 Context Lookup

When the host sends a SETUP token to DEVx EP0:

1. The PIE compares the token address with the DEVx current and temporary
   addresses.
2. The PIE verifies the effective DEVx enable.
3. The PIE selects:
   - function index `1` for DEV0;
   - function index `2` for DEV1.
4. The selected-function indication crosses `usb_synchronizer_1`.
5. Top-level logic selects the corresponding DEVx Function Context:
   - Endpoint List base;
   - data-buffer base;
   - endpoint skip state;
   - buffer-in-use state;
   - endpoint toggle state;
   - SETUP-pending state.
6. The PIE requests the EP0 OUT context.
7. `usb_dma_1` calculates the EP0 context address.
8. `usb_fs_mux_1` selects the software-device RAM path.
9. Top-level RAM routing selects:
   - `ahb_dma_slave_1` for DEV0;
   - `ahb_dma_slave_2` for DEV1.
10. The selected adapter reads EP0 context from the corresponding Endpoint
    RAM.
11. `usb_dma_1` decodes the context.
12. The context crosses back to the PIE.
13. The PIE determines whether the SETUP transaction can be accepted.

## DEVx SETUP Packet Storage

After the SETUP token is accepted:

1. The host transmits the eight-byte DATA0 packet.
2. The PIE validates the packet.
3. The received data and byte count cross `usb_synchronizer_1`.
4. `usb_dma_1` recognizes the SETUP transaction.
5. The DMA selects the SETUP buffer described by the DEVx EP0 context.
6. The RAM write passes through:
   - `usb_fs_mux_1`;
   - DEV0/DEV1 RAM routing;
   - the selected `ahb_dma_slave`.
7. The eight-byte SETUP packet is written into the selected DEVx Endpoint
   RAM.
8. The PIE sends the ACK.
9. The SETUP-received event crosses the Clock-Domain Bridge.
10. Top-level logic routes the event to:
    - `usb_reg_if_1` for DEV0;
    - `usb_reg_if_2` for DEV1.

The selected Register Controller then:

```text
sets usbreg_setup
captures sieint_usbaddress[6:0]
copies the received address into current and temporary address state
initializes EP0 OUT and EP0 IN toggle state
updates the related event and interrupt state
```

Unlike the embedded Hub, DEV0 and DEV1 do not execute a hardware Setup Decode
Table lookup.

The request remains stored in the Endpoint RAM until software reads and
interprets it.

## Software SETUP-Pending Protection

`usbreg_setup` remains asserted until software clears the flag.

Top-level logic selects the pending indication of the current function and
presents it to `usb_dma_1` as:

```text
usbreg_setup_to_dma
```

While the selected software device has an uncleared SETUP request,
`usb_dma_1` modifies the EP0 context returned to the PIE:

```text
epinfo_active = 0
epinfo_stall  = 0
```

The PIE consequently returns NAK to subsequent EP0 transactions.

This prevents the host from advancing the control transfer before software
has:

- read the SETUP packet;
- decoded the request;
- prepared any response payload;
- updated the EP0 context;
- applied any required state change;
- cleared the SETUP-pending indication.

## Software Request Processing

The external control agent uses the DEVx AHB interfaces to:

1. detect the SETUP event or interrupt;
2. read the eight-byte SETUP packet from the DEVx Endpoint RAM;
3. decode:
   - `bmRequestType`;
   - `bRequest`;
   - `wValue`;
   - `wIndex`;
   - `wLength`;
4. determine the required DATA or STATUS stage;
5. apply required register changes;
6. write a response payload when required;
7. update EP0 IN or EP0 OUT context;
8. clear the SETUP-pending bit.

The control and memory paths are distinct:

```text
DEVx Control AHB
  -> usb_ahb_slave_x
  -> usb_reg_if_x
```

```text
DEVx Endpoint RAM AHB
  -> ahb_dma_slave_x
  -> DEVx Endpoint RAM
```

Software-visible device state is controlled through `usb_reg_if_x`.

The SETUP packet, detailed endpoint context, and response payload are stored
in the DEVx Endpoint RAM.

## DEVx Control Read

For a control request with an IN data stage, software:

1. reads and decodes the SETUP packet;
2. determines the response length;
3. writes the response payload into the DEVx Endpoint RAM;
4. programs the EP0 IN context with:
   - active state;
   - byte count;
   - response-buffer address;
   - maximum-packet information;
   - required endpoint attributes;
5. clears the SETUP-pending flag.

When the host sends the next IN token:

1. The PIE selects DEVx.
2. The PIE requests the EP0 IN context.
3. `usb_dma_1` reads the context from the selected Endpoint RAM.
4. The DMA returns the context to the PIE.
5. If EP0 IN is active, the DMA calculates the response-buffer address.
6. `usb_dma_1` reads the response payload from the selected Endpoint RAM.
7. The payload crosses `usb_synchronizer_1`.
8. The PIE transmits the DATA packet.
9. The host returns the handshake.
10. The PIE reports completion and success.
11. `usb_dma_1` updates:
    - the remaining byte count;
    - endpoint active state;
    - payload-buffer position;
    - buffer selection;
    - endpoint toggle;
    - endpoint interrupt state.

For a multi-packet control response, the same context and payload flow
repeats for each subsequent IN token.

After the final data packet, the host sends the zero-length OUT status
transaction through the same PIE, DMA, and selected Endpoint RAM path.

## DEVx Control Write Without a Data Stage

For a control write whose complete meaning is contained in the SETUP packet:

1. Software reads and decodes the SETUP packet.
2. Software applies the requested state change.
3. Software configures EP0 IN for the zero-length status stage.
4. Software clears the SETUP-pending flag.
5. The host sends the status-stage IN token.
6. The PIE requests EP0 IN context.
7. `usb_dma_1` returns the prepared zero-length active context.
8. The PIE transmits the zero-length DATA packet.
9. Transfer completion updates the EP0 state.

## DEVx Control Write With a DATA OUT Stage

The DEV0 and DEV1 RAM-based endpoint model can support a control transfer
with a separate DATA OUT payload.

In that case:

1. Software reads and decodes the SETUP packet.
2. Software allocates a receive buffer in the DEVx Endpoint RAM.
3. Software programs EP0 OUT with:
   - active state;
   - expected byte count;
   - receive-buffer address;
   - required endpoint attributes.
4. Software clears the SETUP-pending flag.
5. The host sends an OUT token and DATA packet.
6. The PIE requests and evaluates EP0 OUT context.
7. The PIE receives and validates the DATA packet.
8. `usb_dma_1` stores the payload in the selected Endpoint RAM.
9. Transfer-completion state and endpoint interrupt state notify software.
10. Software reads and processes the received payload.
11. Software prepares EP0 IN for the zero-length status stage.
12. The PIE executes the final status transaction.

This general control-OUT storage path is possible for DEV0 and DEV1 because
their endpoint contexts and control payloads are RAM based.

No equivalent Hub control-OUT payload use case has been identified in the
hardware Hub implementation.

## DEVx `SET_ADDRESS`

Each DEVx Register Controller maintains:

```text
Current USB address
Temporary USB address
```

During `SET_ADDRESS`:

1. The SETUP packet is received at the current address.
2. Software writes the assigned address into the temporary-address field.
3. The PIE receives both current and temporary addresses.
4. The temporary address allows the PIE to recognize the function during the
   address transition.
5. A subsequent valid SETUP transaction received at the new address causes
   `usb_reg_if_x` to copy the received address into both current and
   temporary address state.

## Primary Debug Observability

The principal signals for a DEVx control transfer are:

```text
Function selection:
  pie_dev_selected
  sync_pie_dev_selected
  usbreg_deviceenabled
  pie_dev_addr
  pie_dev_addr_tmp

Selected Function Context:
  dma_ep_list_start
  dma_data_buffer_start
  dma_ep_skip_selected
  dma_ep_bufinuse_selected
  dma_epinfo_toggle
  usbreg_setup_to_dma

Endpoint RAM path:
  ahb_dma_addr
  ahb_dma_req
  ahb_dma_write
  ahb_dma_wdata
  dev0_dma_req / dev1_dma_req
  dev0_dma_gnt / dev1_dma_gnt
  dev0_dma_rdata / dev1_dma_rdata

Register state:
  usbreg_setup / dev1_usbreg_setup
  usbreg_usbaddress / dev1_usbreg_usbaddress
  usbreg_usbaddress_tmp / dev1_usbreg_usbaddress_tmp

DMA endpoint-state updates:
  dma_clear_toggle
  dma_set_toggle
  dma_set_int
  dma_clear_skip
  dma_physepnr
  dma_skip_ep
```

A valid DEVx control flow should show:

```text
DEVx selected
  -> EP0 OUT context read from DEVx Endpoint RAM
  -> SETUP packet written to DEVx Endpoint RAM
  -> setup_received routed to usb_reg_if_x
  -> SETUP-pending state asserted
  -> EP0 returns NAK while software processes the request
  -> software prepares the next EP0 stage
  -> software clears SETUP pending
  -> next host token uses the updated Endpoint RAM context
```

---

# DEV0 or DEV1 Bulk Transfer

Bulk transfers use non-control endpoint contexts and payload buffers stored
entirely in the selected DEV0 or DEV1 Endpoint RAM.

The shared PIE and Endpoint Data Manager execute the USB transaction.

The external control agent prepares or consumes the payload using the DEVx
Endpoint RAM AHB interface.

Before Bulk traffic begins, the external control agent must configure an
endpoint context containing the required fields, including:

```text
Endpoint active state
Endpoint type
Endpoint direction
Maximum packet size
Transfer byte count
Payload-buffer address
Data-toggle state
Buffer-selection state
Interrupt control
```

The flows below assume that:

- the selected software-device function is enabled;
- the corresponding Hub downstream port is enabled;
- the endpoint context is initialized;
- the payload buffer is allocated.

## Common Bulk Endpoint Context Lookup

For every Bulk IN or Bulk OUT token:

1. The PIE matches the DEVx address.
2. The PIE selects DEV0 or DEV1.
3. The PIE decodes the endpoint number and direction.
4. `pie_dev_selected` crosses `usb_synchronizer_1`.
5. Top-level logic selects the DEVx Function Context.
6. The PIE generates the endpoint-context request.
7. `usb_dma_1` calculates the addressed Endpoint List entry.
8. `usb_fs_mux_1` selects the software-device RAM path.
9. DEV0/DEV1 RAM routing selects the corresponding `ahb_dma_slave`.
10. The selected adapter reads the endpoint context.
11. `usb_dma_1` decodes the returned context.
12. The endpoint information crosses the Clock-Domain Bridge.
13. The PIE determines the resulting USB behavior.

The returned context includes:

```text
active
disabled
STALL state
data toggle
endpoint attributes
available or expected byte count
maximum-packet information
payload-buffer reference
```

---

# Bulk IN Transfer to DEV0 or DEV1

A Bulk IN transfer moves data from the selected DEVx Endpoint RAM to the USB
host.

## Software Preparation

Before the host sends the IN token, the external control agent:

1. allocates a TX buffer in the DEVx Endpoint RAM;
2. writes the TX payload into the buffer;
3. programs the Bulk IN endpoint context;
4. writes the payload-buffer address;
5. writes the transfer byte count;
6. configures maximum-packet and endpoint attributes;
7. marks the endpoint active;
8. enables endpoint-completion interrupts if required.

## Host IN Token

When the host sends the IN token:

1. The PIE matches the DEVx address.
2. The PIE selects the target software device.
3. The PIE identifies the endpoint number and IN direction.
4. The PIE requests the endpoint context.
5. `usb_dma_1` reads the context from the selected Endpoint RAM.
6. The context is returned to the PIE.

The PIE evaluates the returned state:

```text
Endpoint inactive:
  NAK

Endpoint stalled:
  STALL

Endpoint disabled:
  Endpoint-disabled behavior

Endpoint active:
  Continue with TX payload fetch
```

## TX Payload Address Generation

For an active endpoint, `usb_dma_1` obtains the payload reference from the
endpoint context.

The DMA generates the effective payload address using:

```text
Selected data-buffer base
  +
Endpoint buffer reference
  +
Current transfer offset
```

The selected data-buffer base originates from the corresponding
`usb_reg_if`.

The payload reference and current transfer state originate from the endpoint
context stored in the DEVx Endpoint RAM.

## TX Payload Fetch

The payload-fetch sequence is:

1. `usb_dma_1` generates a RAM read.
2. `usb_fs_mux_1` selects the software-device RAM path.
3. Top-level DEV0/DEV1 RAM routing selects the correct adapter.
4. The selected `ahb_dma_slave` drives the native Endpoint RAM interface.
5. The selected Endpoint RAM returns the payload word.
6. `usb_dma_1` selects the required bytes.
7. The DMA provides:

```text
epinfo_sync_txdata[USB_DATAWIDTH-1:0]
epinfo_sync_txdata_valid
```

8. The payload crosses `usb_synchronizer_1`.
9. The PIE transmits the DATA packet using:
   - the selected data toggle;
   - the available byte count;
   - the maximum-packet information.
10. The PIE reports each consumed data word through the TX-data-fetched
    indication.

## Completion and Runtime-State Update

After the host handshake:

1. The PIE reports transfer completion and success.
2. `usb_dma_1` updates the endpoint context in the DEVx Endpoint RAM.
3. The update can include:
   - remaining byte count;
   - payload-buffer position;
   - endpoint active state;
   - buffer-selection state.
4. The DMA generates the required compact-state updates:
   - toggle set or clear;
   - endpoint interrupt set;
   - skip-state update;
   - buffer-in-use update.
5. Top-level logic routes the update strobes to the selected `usb_reg_if`.
6. The selected Register Controller updates its compact endpoint state.
7. DEV0 or DEV1 IRQ/FIQ can be asserted according to the programmed
   interrupt-enable and routing state.

For a transfer larger than one maximum-size packet, the endpoint remains
active and the procedure repeats on subsequent IN tokens until the byte
count is exhausted.

## Primary Debug Observability

The principal Bulk IN signals are:

```text
PIE:
  pie_dev_selected
  pie_epinfo_req
  pie_epinfo_epnr
  pie_epinfo_epdir
  pie_txdata_fetched
  pie_endtransfer
  pie_success

Selected Function Context:
  dma_ep_list_start
  dma_data_buffer_start
  dma_epinfo_toggle
  dma_ep_bufinuse_selected
  dma_ep_skip_selected

Endpoint Data Manager:
  dma_state
  epinfo_sync_active
  epinfo_sync_stall
  epinfo_sync_nbytes
  epinfo_sync_maxpacket
  epinfo_sync_txdata
  epinfo_sync_txdata_valid

Endpoint RAM path:
  ahb_dma_addr
  ahb_dma_req
  dev0_dma_req / dev1_dma_req
  dev0_dma_gnt / dev1_dma_gnt
  dev0_dma_rdata / dev1_dma_rdata

State updates:
  dma_set_toggle
  dma_clear_toggle
  dma_set_int
  dma_clear_skip
  dma_physepnr
```

A valid Bulk IN flow should show:

```text
DEVx and IN endpoint selected
  -> endpoint context read
  -> endpoint active
  -> TX payload read from selected Endpoint RAM
  -> DATA packet transmitted
  -> host handshake
  -> context, toggle, buffer, and interrupt state updated
```

---

# Bulk OUT Transfer to DEV0 or DEV1

A Bulk OUT transfer moves data from the USB host into the selected DEVx
Endpoint RAM.

## Software Preparation

Before the host sends the OUT transaction, the external control agent:

1. allocates an RX buffer in the DEVx Endpoint RAM;
2. programs the Bulk OUT endpoint context;
3. writes the receive-buffer address;
4. writes the expected byte count or available buffer size;
5. configures maximum-packet and endpoint attributes;
6. marks the endpoint active;
7. enables endpoint-completion interrupts if required.

## Host OUT Token

When the host sends the OUT token:

1. The PIE matches the DEVx address.
2. The PIE selects DEV0 or DEV1.
3. The PIE identifies the endpoint number and OUT direction.
4. The PIE requests endpoint context.
5. `usb_dma_1` reads the context from the selected Endpoint RAM.
6. The context is returned to the PIE.
7. The PIE determines whether the endpoint can accept the transaction.

The resulting behavior is:

```text
Endpoint inactive:
  NAK

Endpoint stalled:
  STALL

Endpoint disabled:
  Endpoint-disabled behavior

Endpoint active:
  Accept the DATA packet
```

## RX Payload Reception

For an active endpoint:

1. The host transmits the DATA packet.
2. The PIE receives the packet.
3. The PIE validates PID, length, and CRC.
4. The received payload crosses `usb_synchronizer_1` as:

```text
sync_sieint_rxdata[USB_DATAWIDTH-1:0]
sync_sieint_rxdatavalid
sync_sieint_rx_nbytes[11:0]
```

5. `usb_dma_1` obtains the RX buffer reference from the endpoint context.

## RX Payload Address Generation

The DMA generates the effective RX address using:

```text
Selected data-buffer base
  +
Endpoint receive-buffer reference
  +
Current receive offset
```

The selected function determines whether DEV0 or DEV1 memory information is
used.

## RX Payload Store

The payload-store sequence is:

1. `usb_dma_1` generates a RAM write.
2. `usb_fs_mux_1` selects the software-device RAM path.
3. Top-level routing selects the DEV0 or DEV1 RAM adapter.
4. The DMA supplies:
   - RAM address;
   - write data;
   - write indication;
   - DWORD selection.
5. The selected `ahb_dma_slave` generates:
   - native RAM chip select;
   - native RAM address;
   - write enable;
   - write-data mask.
6. The payload is written into the selected Endpoint RAM.
7. The PIE sends the required USB handshake.

## Completion and Runtime-State Update

After the received packet has been stored:

1. The PIE reports transfer completion and success.
2. `usb_dma_1` updates the endpoint context in the DEVx Endpoint RAM.
3. The update can include:
   - remaining or received byte count;
   - receive-buffer position;
   - endpoint active state;
   - buffer-selection state.
4. The DMA updates the selected `usb_reg_if`:
   - endpoint toggle;
   - endpoint interrupt state;
   - buffer-in-use state;
   - skip state;
   - NAK-related state where applicable.
5. The corresponding IRQ or FIQ can notify the external control agent.
6. The external control agent reads the received payload through the DEVx
   Endpoint RAM AHB interface.
7. Software or the external agent rearms the endpoint when another receive
   buffer is available.

For a multi-packet transfer, the buffer position and remaining byte count are
updated after every accepted packet.

## Primary Debug Observability

The principal Bulk OUT signals are:

```text
PIE:
  pie_dev_selected
  pie_epinfo_req
  pie_epinfo_epnr
  pie_epinfo_epdir
  pie_rxdata
  pie_rxdatavalid
  pie_rx_nbytes
  pie_endtransfer
  pie_success

Clock-Domain Bridge:
  sync_sieint_rxdata
  sync_sieint_rxdatavalid
  sync_sieint_rx_nbytes
  sync_sieint_endtransfer
  sync_sieint_success

Endpoint Data Manager:
  dma_state
  epinfo_sync_active
  epinfo_sync_stall
  epinfo_sync_nbytes
  dma_dma_addr
  dma_dma_req
  dma_dma_write
  dma_dma_wdata
  dma_word_enable

Endpoint RAM path:
  ahb_dma_addr
  ahb_dma_write
  ahb_dma_wdata
  usb_dma_dword_selection_int
  dev0_dma_req / dev1_dma_req
  dev0_mem_cs / dev1_mem_cs
  dev0_mem_a / dev1_mem_a
  dev0_mem_d / dev1_mem_d
  dev0_mem_web_out / dev1_mem_web_out
  dev0_mem_bsel / dev1_mem_bsel

State updates:
  dma_set_toggle
  dma_clear_toggle
  dma_set_int
  dma_clear_skip
  dma_physepnr
```

A valid Bulk OUT flow should show:

```text
DEVx and OUT endpoint selected
  -> endpoint context read
  -> endpoint active
  -> DATA packet received and validated
  -> payload written into selected Endpoint RAM
  -> USB handshake
  -> context, toggle, buffer, and interrupt state updated
```

---

# Architectural Perspective

From the perspective of the shared USB front end, every transaction follows
the same high-level sequence:

```text
USB PIE
  -> USB Clock-Domain Bridge
  -> Endpoint Data Manager
  -> Selected Function
  -> Endpoint Context
  -> Payload or Response Resource
  -> USB PIE
```

The selected function determines how endpoint state and payload data are
obtained.

```text
Embedded Hub

Endpoint runtime context:
  usb_ep_config_handler_1

EP0 SETUP storage and standard-request processing:
  hub_ep0_handler_1

Hub and downstream-port class behavior:
  usb_app_hw_hub_1

Descriptors and stored responses:
  Hub Descriptor RAM

Hub Status Change EP1 IN payload:
  usb_app_hw_hub_1
```

```text
DEV0

Device control and compact endpoint state:
  usb_reg_if_1

Detailed endpoint context and payload:
  DEV0 Endpoint RAM

External request and payload management:
  DEV0 Control AHB and Endpoint RAM AHB interfaces
```

```text
DEV1

Device control and compact endpoint state:
  usb_reg_if_2

Detailed endpoint context and payload:
  DEV1 Endpoint RAM

External request and payload management:
  DEV1 Control AHB and Endpoint RAM AHB interfaces
```

The shared PIE and Endpoint Data Manager remain largely independent of these
implementation differences.

Function-selection and top-level routing logic direct each:

- endpoint-context lookup;
- SETUP event;
- payload access;
- runtime-state update;
- RAM request and response;

toward the resource associated with the selected USB function.

This separation allows the architecture to combine:

- one hardware-managed Hub;
- two software-managed downstream devices;
- one shared USB Protocol and Interface Engine;
- one shared Endpoint Data Manager;

while preserving independent address state, endpoint state, memory contents,
interrupts, and downstream-port behavior for DEV0 and DEV1.

