# Hub Descriptor RAM Programming Guide

## 1. Purpose

The Hub Descriptor RAM contains the programmable EP0 request/response image for the JANUS USB Hub hardware device.

The fixed RTL engine interprets this image to:

- identify supported USB SETUP requests;
- compare each received SETUP packet against programmable patterns and masks;
- select static response data stored in RAM;
- limit the response length;
- dispatch supported requests to hardcoded RTL operations;
- reject unsupported requests through the EP0 unsupported-request path.

The Release 04 image is the validated reference implementation:

    TESTBENCH/DATA/janus_hub_rom_image.svh

The corresponding initialization BFM is:

    TESTBENCH/MODELS/janus_hub_desc_init_bfm.sv

The RAM image was internal and invisible to the integrator in the legacy implementation. Since the Hub descriptor storage is now externally programmable, the integrator is responsible for providing a valid and self-consistent image.

The Release 04 image should be used as the starting point for future integrations.



## 2. Terminology

This document uses the following terminology:

- Byte: 8 bits
- HalfWord: 16 bits
- Word: 32 bits
- DWord: 64 bits
- Byte address: RAM or AHB address expressed in bytes
- Word index: index of a 32-bit Word

The internal EP0 memory addresses are Word indices.

The Hub Descriptor RAM AHB interface uses byte addresses.

The conversion is:

    byte address = Word index * 4

For example:

    Word index 0x030 = byte address 0x00C0
    Word index 0x0F0 = byte address 0x03C0

Care must be taken not to interpret a Word index as a byte address.



## 3. Architectural Overview

The programmable image contains three logical areas:

1. Descriptor area
2. Setup Decode Table
3. Device Link Table

The request-processing sequence is:

    USB SETUP packet
      -> hardware-device selection
      -> Device Link Table lookup
      -> Setup Decode Table scan
      -> pattern and mask comparison
      -> response-buffer selection or RTL-operation dispatch
      -> EP0 response

The main RTL modules involved are:

    RTL/RTL/usb_ep0_handler.m.vhdl
    RTL/RTL/usb_ep_config_handler.m.vhdl
    RTL/RTL/usb_dma.m.vhdl
    RTL/RTL/usb_app_hw_hub.m.vhdl

The fixed RTL implements the request-processing engine.

The RAM image defines:

- the supported SETUP requests;
- the matching patterns and masks;
- the static response locations;
- the maximum response lengths;
- the internal RTL action associated with each matching request;
- the end of each decode table.

The resulting architecture can be considered a limited declarative EP0 microcode mechanism:

- matching and dispatch are programmed through RAM;
- the processing algorithm is fixed in RTL;
- the available internal actions are hardcoded in RTL.

The RAM image cannot define a new RTL operation. It can only dispatch a matching SETUP request to an operation already implemented by the hardware.





## 4. Release 04 Reference Memory Map

The validated Release 04 image contains 173 initialized Words.

| Byte range    | Word range  | Size      | Purpose                            |
|---------------|-------------|-----------|------------------------------------|
| 0x0000-0x003F | 0x000-0x00F | 64 bytes  | Hub Device Descriptor slot         |
| 0x0040-0x007F | 0x010-0x01F | 64 bytes  | Hub Configuration Descriptor slot  |
| 0x0080-0x00BF | 0x020-0x02F | 64 bytes  | Hub Class Descriptor slot          |
| 0x00C0-0x022F | 0x030-0x08B | 368 bytes | Hub Setup Decode Table             |
| 0x0300-0x033F | 0x0C0-0x0CF | 64 bytes  | Hub Device Qualifier slot          |
| 0x0380-0x03BF | 0x0E0-0x0EF | 64 bytes  | Hub Other-Speed Configuration slot |
| 0x03C0-0x03C3 | 0x0F0`      | 4 bytes   | Hub Device Link entry              |

The address gaps are intentionally not initialized by the Release 04 BFM.


The Release 04 Hub has two downstream ports:
- Hub Port 1: software Device0
- Hub Port 2: software Device1

The Hub descriptor field `bNbrPorts` is therefore set to `2`.






## 5. Descriptor Area

Static USB responses are placed in slots with a granularity of 64 bytes.

For a static-response selector with bit 7 set, the physical slot offset is:

    physical byte offset = selector[6:0] * 64

Examples:

    selector 0x80
      selector[6:0] = 0x00
      physical byte offset = 0x00 * 64 = 0x0000

    selector 0x81
      selector[6:0] = 0x01
      physical byte offset = 0x01 * 64 = 0x0040

    selector 0x82
      selector[6:0] = 0x02
      physical byte offset = 0x02 * 64 = 0x0080

    selector 0x8C
      selector[6:0] = 0x0C
      physical byte offset = 0x0C * 64 = 0x0300

    selector 0x8E
      selector[6:0] = 0x0E
      physical byte offset = 0x0E * 64 = 0x0380

The selector is stored in the matching Setup Decode Table record.

The complete payload associated with a selector must be initialized before the Hub is enabled or connected.






## 6. Device Link Table

The Device Link Table selects the Setup Decode Table associated with each hardware device.

Its starting Word index is configured in:

    RTL/INTERFACE/usb_ep_config_hub_pkg.p.vhdl

Release 04 uses:

    C_DEV_LINK_START = X"0F0"

This corresponds to byte address:

    0x0F0 * 4 = 0x03C0

Release 04 contains one hardware device:

    C_NBDEV = 1

The only hardware device is:

    hardware device 0 = Hub

Only one Device Link entry is therefore required.

The entry at byte address 0x03C0 contains:

    0x00000030

The value is the Word index of the Hub Setup Decode Table:

    Setup Decode Table Word index = 0x030
    Setup Decode Table byte address = 0x030 * 4 = 0x00C0

The resulting lookup is:

    hardware device 0
      -> Device Link entry at Word index 0x0F0
      -> Device Link entry byte address 0x03C0
      -> entry content 0x00000030
      -> Hub Setup Decode Table Word index 0x030
      -> Hub Setup Decode Table byte address 0x00C0

A change to the Setup Decode Table location requires a corresponding update to the Device Link entry.

A change to the Device Link Table location requires a corresponding update to `C_DEV_LINK_START`.

For multiple hardware devices, the Device Link entries are consecutive Words:

    device N Device Link Word index =
      C_DEV_LINK_START + N

The number of valid Device Link entries must agree with `C_NBDEV`.


## 7. Setup Decode Table

The Release 04 Hub Setup Decode Table begins at byte address:

    0x00C0

Its corresponding Word index is:

    0x030

Each decode record contains four consecutive 32-bit Words and occupies 16 bytes.

The records are scanned sequentially until:

- a matching record is found; or
- a non-matching record with the `LAST` bit set is reached.

The Release 04 Hub Setup Decode Table contains 23 records.





## 8. USB SETUP Packet Format

A USB SETUP packet contains eight bytes:

| Byte | Field        |
|-----|---------------|
| 0   | bmRequestType |
| 1   | bRequest      |
| 2-3 | wValue        |
| 4-5 | wIndex        |
| 6-7 | wLength       |

The SETUP packet is compared against the pattern and mask contained in each Setup Decode Table record.




## 9. Setup Decode Record Format

Each Setup Decode Table record consists of four Words.


### 9.1 Word 0

| Bits     | Meaning                                          |
|----------|--------------------------------------------------|
|  [15:0]  | Exact pattern for  bmRequestType  and  bRequest  |
|  [31:16] | Expected  wValue after masking                   |

The exact lower comparison is:

    received SETUP[15:0] == Word0[15:0]

This compares:

    bmRequestType
    bRequest

No mask is applied to bmRequestType or bRequest.

The wValue comparison is:

    (received wValue AND Word1[31:16]) == Word0[31:16]



### 9.2 Word 1

| Bits    | Meaning                       |
|---------|-------------------------------|
| [31:16] | Mask applied to wValue        |
| [15:8]  | Response-buffer selector      |
| [7]     | LAST  record marker           |
| `[6:0]` | Internal setup_request code   |

When Word 1 bits [15:14] are not 00, bits [15:8] are loaded into "setup_data_buffer".

When Word 1 bits [15:14] are 00, the buffer selector is derived internally from the hardware-device index.

The response-buffer selector is transferred through:

    setup_data_buffer
      -> ep0_data_buffer
      -> reg_ep0_data_buffer
      -> EP0 Address Offset
      -> usb_dma epinfo_addr_offset
      -> response payload address

For static descriptors, selector bit 7 identifies the internally routed EP0 response area, while selector bits [6:0] identify a 64-byte slot.

The LAST bit identifies the final decode record.

If a record does not match and LAST = 0, the hardware continues with the next record.

If a record does not match and LAST = 1, the scan terminates and the request follows the EP0 unsupported-request path.

The setup_request field dispatches the matching request to an RTL operation already implemented by the hardware.

The RAM image can select an existing operation but cannot define a new operation.



### 9.3 Word 2

| Bits     | Meaning                          |
|----------|----------------------------------|
|  [15:0]  | Expected  wIndex  after masking  |
|  [31:16] | Maximum response length in bytes |

The wIndex comparison is:

    (received wIndex AND Word3[15:0]) == Word2[15:0]

The response length is:

    effective response length =
      minimum(received wLength, Word2[31:16])

The received `wLength` does not participate in the record match.

It limits the amount of data transferred after a record has matched.



### 9.4 Word 3

| Bits      | Meaning                               |
|-----------|---------------------------------------|
|  [15:0]   | Mask applied to wIndex                |
|  [31:16]  | Unused by the analyzed implementation |

Only Word 3 bits [15:0] participate in the matching process implemented by usb_ep0_handler.






## 10. Decode Example: Hub Device Descriptor

The first Release 04 Hub decode record is:

    Word 0 = 0x01000680
    Word 1 = 0xFFFF8000
    Word 2 = 0x00120000
    Word 3 = 0x0000FFFF

It decodes as:

    bmRequestType       = 0x80
    bRequest            = 0x06
    expected wValue     = 0x0100
    wValue mask         = 0xFFFF
    response selector   = 0x80
    LAST                = 0
    internal request    = 0x00
    expected wIndex     = 0x0000
    maximum length      = 0x0012
    wIndex mask         = 0xFFFF

This record recognizes:

    GET_DESCRIPTOR(Device, index 0)

The response selector 0x80 selects the descriptor slot at byte address:

    0x0000

The maximum response length is:

    0x0012 = 18 bytes

This agrees with the standard USB Device Descriptor length.






## 11. Internal Request Codes

The lower seven bits of Word 1 contain the internal "setup_request" code.

The Hub class request codes are:

| Value  | RTL operation   |
|--------|-----------------|
|  0x40  |  CLEAR_FEATURE  |
|  0x41  |  SET_FEATURE    |
|  0x42  |  GET_STATUS     |

These operations are implemented in:

    RTL/RTL/usb_app_hw_hub.m.vhdl

Records using these request codes dispatch the matching request to dynamic Hub logic rather than selecting only a static USB descriptor.

For example:

- CLEAR_FEATURE may clear a port connection-change or reset-change indication;
- SET_FEATURE  may enable, suspend or reset a downstream port;
- GET_STATUS  selects the Hub or port status returned by the Hub class logic.

Other standard internal request codes are defined in:

    RTL/INTERFACE/usb_ep_config_hub_pkg.p.vhdl

The numeric meaning of an internal request code is fixed by RTL.

Assigning an unsupported or incorrect code in RAM does not create a new operation.





## 12. Static and Dynamic Responses


The Hub EP0 behavior includes two types of response.


### 12.1 Static response

A static response is read from a 64-byte RAM slot.

Examples include:

- Device Descriptor;
- Configuration Descriptor;
- Hub Class Descriptor;
- Device Qualifier;
- Other-Speed Configuration.

The matching Setup Decode Table record contains the associated response-buffer selector.


### 12.2 Dynamic response

A dynamic response is generated or controlled by RTL.

Examples include:

- Hub status;
- downstream port status;
- port reset;
- port enable;
- connection-change clearing;
- reset-change clearing.

The matching Setup Decode Table record contains an internal "setup_request" code such as "0x40", "0x41" or "0x42".

The request is then handled by:

    RTL/RTL/usb_app_hw_hub.m.vhdl






## 13. AHB Initialization

The reference image is initialized through:

    TESTBENCH/MODELS/janus_hub_desc_init_bfm.sv

The BFM includes:

    TESTBENCH/DATA/janus_hub_rom_image.svh

Each image entry contains:

    hub_rom_addr[i] = byte address
    hub_rom_data[i] = 32-bit Word data

The BFM performs one AHB Word write for each image entry:

    for (i = 0; i < HUB_ROM_WORDS; i++)
      ahb_write32(hub_rom_addr[i], hub_rom_data[i]);

Release 04 defines:

    HUB_ROM_WORDS = 173

The initialization therefore requires 173 AHB Word writes.

The legacy image required:

    514 AHB Word writes

Release 04 removes:

    341 AHB Word writes

The reduction is approximately:

    66 percent

The BFM does not require the addresses to be contiguous.

Only the addresses explicitly present in hub_rom_addr[] and hub_rom_data[] are initialized.

The Release 04 image intentionally omits unused gaps.




## 14. Initialization Order

The Hub Descriptor RAM must be initialized before the Hub is enabled or connected upstream.

The recommended order is:

1. Keep the Hub disabled and disconnected.
2. Initialize all image Words through the AHB interface.
3. Enable the Hub.
4. Connect the Hub upstream.




Enabling or connecting the Hub before completing RAM initialization may allow EP0 to access uninitialized descriptor or decode-table data.

## 15. Programming Requirements

A valid image must satisfy all the following requirements.

1. C_DEV_LINK_START must contain the Word index of the first Device Link entry.

2. Device Link entry must contain the Word index of the associated Setup Decode Table.

3. Every Setup Decode Table record must contain four initialized Words.

4. At least one record in each Setup Decode Table must have LAST = 1.

5. Every static-response selector must point to an initialized 64-byte slot.

6. Descriptor lengths must agree with the descriptor payload.

7. Word 2 maximum response length must not exceed the initialized response data.

8. The Hub descriptor bNbrPorts must agree with the implemented number of Hub ports.

9. The Hub descriptor bNbrPorts must agree with C_HUB_NB_PORTS.

10. Internal "setup_request" codes must correspond to supported RTL operations.

11. The Setup Decode Table, descriptor slots and Device Link Table must not overlap.

12. All multi-byte USB fields must use USB little-endian byte order.

13. The RAM image must be initialized before Hub enable and upstream connection.

14. Any change to the location of a descriptor slot must be reflected in the response selector of every record that references it.

15. Any change to the Setup Decode Table location must be reflected in the corresponding Device Link entry.

16. Any change to the Device Link Table location must be reflected in C_DEV_LINK_START.




