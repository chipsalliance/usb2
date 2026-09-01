# USB IP Release Notes

## Release 01 - Original DUT Baseline

Reference baseline containing:

- original compound USB DUT;
- Hub with legacy CMSIS-DAP/JTAG device and one software-controlled USB device;
- enumeration of the Hub and software-controlled device;
- EP0 control transfers;
- EP1 bulk OUT and IN transfers;
- USB host and UTMI testbench environment.


## Release 02 - Dual Software Device

Extends Release 01 with:

- second software-controlled USB device;
- additional register, DMA, RAM, IRQ, and FIQ interfaces;
- updated Hub port mapping;
- enumeration of both software-controlled devices;
- EP1 bulk OUT and IN transfers on the dual-device architecture;
- reset, connection, interrupt, and suspend handling.


## Release 03 - Hub Descriptor RAM

Extends Release 02 with:

- dedicated AHB interface for Hub descriptor memory;
- external 16 KiB Hub descriptor RAM;
- 514-Word descriptor and request-table image;
- Hub EP0 served from descriptor RAM;
- legacy Hub EP0 ROM removed from the active datapath;
- software-controlled HUB_EN and HUB_DCON;
- legacy USB_EnableHub mode preserved;
- self-contained RTL, testbench, batch, and GUI simulation package.

Validated final result:

    JANUS smoke test PASS: bulk OUT/IN complete, final SOFs complete, Device2 suspended


## Release 04 - Legacy CMSIS-DAP/JTAG Removal

Extends Release 03 with:

- complete removal of the legacy CMSIS-DAP/JTAG hardware device;
- removal of the internal JTAG endpoint packet-buffer handler;
- removal of the external CMSIS clock, reset, status, and JTAG interfaces;
- removal of the legacy JTAG descriptor data, Setup Decode Table, and Device Link entry;
- removal of the inactive legacy Hub EP0 ROM sources and bindings;
- reduction of the Hub from three to two downstream ports;
- software Device0 remapped to Hub Port 1;
- software Device1 remapped to Hub Port 2;
- Hub descriptor updated to report bNbrPorts = 2;
- Hub endpoint configuration reduced to the single Hub interrupt IN endpoint;
- Hub Descriptor RAM image reduced to Hub-only content;
- Hub Setup Decode Table relocated from byte address 0x03F0 to 0x00C0;
- Hub Device Link entry relocated from byte address 0x0800 to 0x03C0;
- C_DEV_LINK_START updated from Word index 0x200 to 0x0F0;
- Hub Setup Decode Table pointer updated from Word index `0x0FC` to `0x030`;
- Hub Descriptor RAM initialization reduced from 514 to 173 AHB Word writes, removing 341 writes, approximately 66 percent;
- dedicated Hub Descriptor RAM programming guide added under docs/.

Programming reference:

    docs/HUB_DESCRIPTOR_RAM_PROGRAMMING_GUIDE.md

Validated final result:

    JANUS smoke test PASS: bulk OUT/IN complete, final SOFs complete, Device2 suspended.
