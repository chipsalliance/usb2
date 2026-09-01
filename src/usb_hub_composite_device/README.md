# USB IP - Release 04 JTAG Removal and Compact Hub Descriptor RAM

## Contents

This self-contained package includes:

- RTL sources under RTL/
- testbench and behavioral models under TESTBENCH/
- RTL file list: RTL/rtl.inpfiles
- testbench file list: TESTBENCH/tb.inpfiles
- Xcelium scripts and SimVision configuration under nccoex/

No source file outside this package is required.

## Run the Complete Test

From the package root:

    cd nccoex
    ./run_all.sh

This command:

1. compiles the RTL;
2. compiles the testbench and models;
3. elaborates the design;
4. runs the complete batch regression;
5. checks the final PASS message.

Expected final output:

    [OK] JANUS smoke test PASS
    [OK] Release 04 clean build and regression completed

## Run in GUI

First build and elaborate:

    cd nccoex
    ./compile_rtl.sh
    ./compile_tb.sh
    ./elaborate.sh

Then launch SimVision:

    ./run_gui.sh

Start the simulation from the Xcelium console with:

    run

The GUI uses the local simvision.svcf and stores waveforms in nccoex/waves.shm.

## Clean Generated Files

From nccoex:

    ./clean.sh

Then rebuild and rerun with:

    ./run_all.sh


## Release 04 Architecture

Release 04 removes the legacy CMSIS-DAP/JTAG hardware device and retains:

- the USB Hub;
- software Device0 on Hub Port 1;
- software Device1 on Hub Port 2.

The Hub therefore exposes two downstream ports, and the Hub descriptor reports:

    bNbrPorts = 2

The legacy JTAG application, endpoint packet buffers, external JTAG interface, clock logic, descriptor data, Setup Decode Table, and Device Link entry have been removed.

## Hub Descriptor RAM

The validated Hub-only RAM image is:

    TESTBENCH/DATA/janus_hub_rom_image.svh

The image contains:

- Hub USB descriptors;
- the Hub EP0 Setup Decode Table;
- the Hub Device Link entry.

The compact Release 04 image requires:

    HUB_ROM_WORDS = 173

The previous legacy image required 514 AHB Word writes. Release 04 reduces the initialization sequence by 341 writes, approximately 66 percent.

The Hub Descriptor RAM programming format, memory map, decode-record structure, addressing rules, and initialization requirements are described in:

    docs/HUB_DESCRIPTOR_RAM_PROGRAMMING_GUIDE.md

The Descriptor RAM must be initialized before enabling or connecting the Hub.



## Test Summary

The test initializes the Hub descriptor RAM, enables and connects the Hub, enumerates the Hub and the two downstream software devices, verifies bulk OUT and IN transfers, completes the final SOF sequence, and checks the final suspend events.

The successful testbench message is:

    JANUS smoke test PASS: bulk OUT/IN complete, final SOFs complete, Device2 suspended

The VHDL testbench intentionally terminates a successful run with an assertion of severity failure. The run is considered successful when the PASS message above is present in the log.
