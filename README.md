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

## SystemRDL validation and generation

`tools/scripts/usb2_reg_gen.py` is the authoritative SystemRDL compiler and
OCP Recovery register generator. Install the pinned CI dependencies with:

```sh
python3 -m pip install -r tools/scripts/requirements-rdl.txt
```

The pinned tool versions are:

| Package | Version |
|---|---|
| SystemRDL Compiler | 1.27.3 |
| PeakRDL-regblock | 0.21.0 |
| PeakRDL-uvm | 2.3.0 |
| PeakRDL-html | 2.10.1 |

Validate the addrmap sources without generating files:

```sh
for rdl in usb_combo usb_hub usb_ocp_recovery_reg usbhsd usbhsh; do
  python3 tools/scripts/usb2_reg_gen.py \
    "systemrdl/${rdl}.rdl" --validate-only
done
```

`usb_device_memory.rdl` defines a top-level memory component rather than an
addrmap, so validate it with compile-only mode:

```sh
python3 tools/scripts/usb2_reg_gen.py \
  systemrdl/usb_device_memory.rdl --validate-only --compile-only
```

Regenerate the checked-in OCP Recovery register collateral with:

```sh
python3 tools/scripts/usb2_reg_gen.py \
  systemrdl/usb_ocp_recovery_reg.rdl \
  src/integration/rtl/generated
```

The pull-request RDL workflow runs these validations and regenerates Recovery
outputs in temporary storage. It fails if the generated file set or contents
do not exactly match the checked-in collateral.

The same pull-request workflow runs
`.github/scripts/license_header_check.sh` to require Apache-2.0 SPDX headers on
tracked source, script, workflow, filelist, and RDL files. The two
PeakRDL-generated SystemVerilog modules are excluded because regeneration
replaces their file headers.

## VHDL source-set selection

VHDL sources and configuration bindings use `work`, meaning the library into
which the current design unit is analyzed. The local `.f` files select that
physical library with `-work rtl`; this does not require `rtl`-qualified source
references.

Use separate build output/library directories for the following alternatives:

| Design | Source filelists |
|---|---|
| Standalone 3516 | VHDL: `src/cfg/rtl_base_filelist.f`, `src/cfg/usb_ip_3511_filelist.f`, `src/cfg/usb_ip_3515_filelist.f`, `src/cfg/usb_ip_3516_filelist.f`; SystemVerilog: `src/cfg/usb_verilog_top_filelist.f` |
| Compound Hub and two devices | VHDL: `src/cfg/usb_ip_hub_composite_device.f`; SystemVerilog: `src/cfg/usb_compound_verilog_filelist.f` |

Do not combine the alternative VHDL source sets in one library: several
packages and entities have identical names but different implementations. The
standalone set selects
`ip_xxx_3511/INTERFACE/usb_ep_config_pkg.p.vhdl`; the compound set selects
`usb_hub_composite_device/RTL/INTERFACE/usb_ep_config_hub_pkg.p.vhdl`, which
also declares `usb_ep_config_pkg`.

Both source sets include the same post-sync recovery arbiter source. The
compound structure qualifies Recovery for Device 0 and inserts the arbiter
between the shared synchronizer and DMA. The compound SystemVerilog wrapper
connects the Combo Recovery aperture to `usb_ocp_recovery_top` and exports
`payload_available` and `ocp_firmware_activated`.

The existing `run_compile.csh` invokes the standalone VHDL filelists and
`usb_verilog_top_filelist.f`. It is not a compound build entrypoint. A compound
build should analyze `usb_ip_hub_composite_device.f`, then compile
`usb_compound_verilog_filelist.f`, and elaborate the compound wrapper from its
own integration target.

## VHDL libraries

Internal package, entity, and configuration references use `work`, meaning the
current compilation library. Compile the dependent VHDL units in each selected
source set into the same library; the build can choose its name, such as `rtl`
or `usb_lib`. Architecture names such as `rtl` are independent of library
names.
