# usb

This is the USB2.0 Host + device controller IP

Language : vhdl + verilog

Top level wrapper : ip_xxx_3516_hs_mem_wrapper

This repository uses `caliptra-rtl` as a Git submodule. Initialize it after
cloning:

```sh
git submodule update --init --recursive
```

Alternatively, clone this repository with `--recurse-submodules`.

To update the pinned submodule revision from the configured `main` branch:

```sh
git submodule update --remote submodules/caliptra-rtl
```

To compile: `cd tools/scripts && ./run_compile.csh` (VCS version: W-2024.09-SP1_Full64)

## VHDL libraries

Internal package, entity, and configuration references use `work`, meaning the current compilation library. Compile the dependent VHDL units in each selected source set into the same library; the build can choose its name, such as `rtl` or `usb_lib`. Architecture names such as `rtl` are independent of library names.
