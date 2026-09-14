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

To compile : ./run_compile (VCS verion : Version W-2024.09-SP1_Full64)
