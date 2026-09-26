# Copilot Instructions

## Project Overview

USB 2.0 compound Hub + two-Device Controller IP.

**The primary target component is `ip_xxx_3511_hs_mem_compound_wrapper.sv`** (`src/integration/rtl/`) and its underlying hierarchy (the "compound Hub + two devices" build — see Architecture below) — this is the design under active development.

The originally top-level `ip_xxx_3516_hs_mem_wrapper` (Verilog) — which wraps the VHDL IP core `ip_xxx_3516_hs_mem`, itself built on the base IP `ip_xxx_3511` — is obsolete and will be removed in the future; don't invest effort extending it.

This repository uses `caliptra-rtl` as a Git submodule. Initialize it after cloning with `git submodule update --init --recursive` (or clone with `--recurse-submodules`). To bump the pinned revision from the configured `main` branch: `git submodule update --remote submodules/caliptra-rtl`.

## Build & Simulation

Uses **Synopsys VCS** (Y-2026.03-SP1). No Makefile — compilation is driven by a csh script:

```sh
cd tools/scripts
./run_compile.csh
```

The script:
1. Creates four compilation libraries: `usb_lib`, `lib_usb_ip_3511`, `lib_usb_ip_3515`, `lib_usb_ip_3516`
2. Compiles VHDL via `vhdlan -full64` using `.f` filelist files in `src/cfg/`
3. Compiles Verilog via `vlogan -sverilog`
4. Elaborates with `vcs`, then runs `./simv`

Environment variable `$USB_COMPILE_DIR` must be set — it's the output directory for compiled libraries (see `tools/scripts/synopsys_sim.setup`).

**`run_compile.csh` targets the obsolete standalone 3516 design** (base VHDL filelists + `usb_verilog_top_filelist.f` + `usb_top_tb.sv`), not the compound Hub/device design described above. It cannot simply be repointed at the compound build: there is no equivalent testbench for `ip_xxx_3511_hs_mem_compound_wrapper` yet (only `src/integration/tb/usb_top_tb.sv`, which instantiates the 3516 wrapper). Do not treat this script as validating the compound design; a compound-targeted build/tb still needs to be written (see "VHDL source-set selection" below for the filelists it should use).

There are no lint or unit test commands beyond the VCS compilation/simulation flow.

## SystemRDL validation and generation

`tools/scripts/usb2_reg_gen.py` is the authoritative SystemRDL compiler and OCP Recovery register generator, run in CI by `.github/workflows/pull-request-checks.yml`. Install pinned tool versions with:

```sh
python3 -m pip install -r tools/scripts/requirements-rdl.txt
```

Pinned versions: SystemRDL Compiler 1.27.3, PeakRDL-regblock 0.21.0, PeakRDL-uvm 2.3.0, PeakRDL-html 2.10.1.

**Only `systemrdl/usb_ocp_recovery_reg.rdl` is a real source of generated RTL** — its output (`usb_ocp_recovery_reg_pkg.sv`, `usb_ocp_recovery_reg.sv`, address-def header) is checked into `src/integration/rtl/generated/` and compiled into the design (see `usb_compound_verilog_filelist.f`). The other `.rdl` files (`usb_combo`, `usb_hub`, `usbhsd`, `usbhsh`, `usb_device_memory`) are **documentation-only artifacts** describing register maps — CI validates that they still compile/elaborate cleanly, but nothing generates or checks in RTL from them, and no RTL in this repo is built from their output.

Validate an addrmap source (no file generation) — do this for any `.rdl` edit:

```sh
python3 tools/scripts/usb2_reg_gen.py "systemrdl/<name>.rdl" --validate-only
```

Valid `<name>` values: `usb_combo`, `usb_hub`, `usb_ocp_recovery_reg`, `usbhsd`, `usbhsh`. `usb_device_memory.rdl` defines a top-level memory component (not an addrmap), so validate it with `--validate-only --compile-only` instead.

Regenerate checked-in OCP Recovery collateral (CI fails if generated output doesn't exactly match what's checked in):

```sh
python3 tools/scripts/usb2_reg_gen.py \
  systemrdl/usb_ocp_recovery_reg.rdl \
  src/integration/rtl/generated
```

CI also runs `.github/scripts/license_header_check.sh`, requiring Apache-2.0 SPDX headers on tracked source, script, workflow, filelist, and RDL files (the two PeakRDL-generated SystemVerilog modules are excluded since regeneration replaces their headers).

## Architecture

The primary target is `ip_xxx_3511_hs_mem_compound_wrapper.sv` (`src/integration/rtl/`) — an AXI wrapper around the `usb_hub_composite_device` VHDL IP (`u_hub_compound`, compiled from `usb_ip_hub_composite_device.f`). It exposes a Hub plus two USB device controllers (DEV0, DEV1) behind AXI, with an internal AHB fabric:

```
ip_xxx_3511_hs_mem_compound_wrapper.sv   ← AXI wrapper (Combo/DEV0-mem/DEV1-csr/DEV1-mem AXI subordinates)
├── axi_to_ahb (x3/x4)                   ← One per external AXI interface pair
├── usb_compound_ahb_decoder             ← Splits the Combo AXI port's AHB into DEV0-CSR / Recovery / Hub targets
├── usb_ocp_recovery_top                 ← OCP Recovery register block + transport (generated regs + ctrl decode/arbiter)
└── u_hub_compound (usb_hub_composite_device VHDL)
    ├── Hub control + descriptor store (self-initializing flip-flop array, not external SRAM)
    ├── DEV0 (dev0_ahbs* CSR/DMA ports) ← Recovery-qualified device; arbiter sits between synchronizer and DMA
    └── DEV1 (dev1_ahbs* CSR/DMA ports)
```

Address map (Combo AXI port only; see `usb_compound_pkg.sv`): DEV0 CSR at `0x000`, OCP Recovery registers at `0x800`, Hub registers at `0x1000`+ (aperture sized by `C_HUB_FIFO_SIZE`, default 172 words).

There is **no host-mode logic** in the compound design (no `host_*` ports) — it is device/hub-only, unlike the obsolete 3516 wrapper below.

The standalone `ip_xxx_3516_hs_mem_wrapper` hierarchy is obsolete and retained only for reference until it is removed:

```
ip_xxx_3516_hs_mem_wrapper.v   ← Top-level Verilog integration wrapper
└── ip_xxx_3516_hs_mem         ← Primary VHDL IP (HS + embedded RAM)
    └── ip_xxx_3511            ← Core USB controller (reused across variants)
        ├── usb_sie            ← Serial Interface Engine
        ├── usb_pie / usb_host_pie   ← Parallel Interface Engine (device/host)
        ├── usb_dma / usb_host_dma   ← DMA engine (device/host)
        ├── usb_ahb_slave / usb_ahb_master
        ├── usb_reg_if / usb_host_reg_if
        ├── usb_clkrec         ← Clock recovery
        └── usb_synchronizer   ← CDC synchronizers
```

**Clock domains:**
- Compound wrapper: a single AXI clock/reset pair (`usb_axi_aclk` / `usb_axi_aresetn`) drives the AHB fabric and both devices; `utmi_clk` / `ulpi_clk` are separate PHY clocks (mutually exclusive), async to the AXI clock.
- Obsolete 3516 wrapper (defined in `tools/sdc/ip_3516_hs_mem.sdc.tcl`): three AHB clocks (`ahb_clk_dev`, `ahb_clk_host`, `ahb_clk_dma`, synchronous group) plus the same PHY clocks. There is no equivalent SDC yet for the compound design.

**IP variants** (each has its own `INTERFACE/` + `STRUCTURE/` or `RTL/` subdirs under `src/`):
- `usb_hub_composite_device` — Hub + two composite USB devices (primary target; underlies the compound wrapper)
- `ip_xxx_3511` — base IP (device-mode focus; obsolete-path only)
- `ip_xxx_3511_hs` — high-speed variant (obsolete-path only)
- `ip_xxx_3515_hs` — alternate high-speed variant (obsolete-path only)
- `ip_xxx_3516_hs_mem` — high-speed + embedded RAM (obsolete, used only by the standalone wrapper)

## File Naming Conventions

VHDL files use suffixes that encode their role (applies to both `usb_hub_composite_device` and the obsolete `ip_xxx_3511`/`ip_xxx_3516_hs_mem` trees):

| Suffix | Role |
|--------|------|
| `.p.vhdl` | Package (type/constant declarations) |
| `.e.vhdl` | Entity (port interface) |
| `.m.vhdl` | Module / RTL implementation |
| `.a.vhdl` | Architecture / structural composition |
| `.c.vhdl` | Configuration (binds architecture to entity) |

## Signal Naming Conventions

Port prefixes in the compound wrapper and `usb_hub_composite_device` VHDL follow a consistent scheme:

| Prefix | Domain |
|--------|--------|
| `dev0_` / `dev1_` | DEV0 / DEV1 USB device controller (compound design) |
| `hub_` | Hub control/descriptor AHB port (compound design) |
| `combo_` | Shared Combo AXI port feeding DEV0-CSR/Recovery/Hub (compound design) |
| `recovery_` / `rec_` | OCP Recovery register block / arbiter datapath (compound design) |
| `utmi_` | UTMI PHY interface |
| `ulpi_` | ULPI PHY interface |
| `ahbs_` / `ahbm_` | AHB slave / master (both designs) |
| `mem_` | Embedded RAM / packet SRAM interface |

Obsolete 3516-only prefixes: `dev_` (single device), `host_` (host mode — not present in the compound design), `SIE_`/`PIE_` (internal component interfaces, uppercase).

## Key Configuration Parameters

Compound wrapper parameters (`src/integration/rtl/ip_xxx_3511_hs_mem_compound_wrapper.sv`), forwarded to the `usb_hub_composite_device` VHDL generics:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `C_HUB_FIFO_SIZE` | 172 | Words in the hub descriptor flip-flop array; sets `hub_ahbs_haddr` width and the Hub register aperture |
| `C_DEV0_RAM_ADDRWIDTH` / `C_DEV1_RAM_ADDRWIDTH` | 15 | Per-device EP-list/data-buffer packet SRAM address width |
| `C_DEV0_NBPHYSEP` / `C_DEV1_NBPHYSEP` | 14 | Number of physical endpoints per device (must be a multiple of 2) |
| `C_EPUB` | 32 | Endpoint input buffer size |
| `C_DAUB` | 32 | Data array user buffer size |
| `C_DALB` | 17 | Data array list buffer size |
| `C_SINGLE_BUFFER_SUPPORTED` | 1 | Enable single-buffer mode (applied to both devices) |
| `C_DOUBLE_BUFFER_SUPPORTED` | 1 | Enable double-buffer mode (applied to both devices) |
| `C_TOGGLE_REG_READABLE` | 1 | Expose toggle registers as readable |

Obsolete 3516 wrapper parameters (`ip_xxx_3516_hs_mem_wrapper.v`): `RAM_ADDRWIDTH` (9), `C_NBPHYSEP` (14, single device), `C_ULPI_SUPPORT` / `C_UTMI_SUPPORT` (1) — not applicable to the compound design.

## VHDL source-set selection

There are two mutually exclusive VHDL source sets — never combine them in one library, because several packages/entities share names but differ in implementation (e.g. `usb_ep_config_pkg` is declared both by `ip_xxx_3511/INTERFACE/usb_ep_config_pkg.p.vhdl` and by `usb_hub_composite_device/RTL/INTERFACE/usb_ep_config_hub_pkg.p.vhdl`):

| Design | VHDL filelists | Verilog filelist |
|---|---|---|
| Compound Hub + two devices (primary target) | `usb_ip_hub_composite_device.f` | `usb_compound_verilog_filelist.f` |
| Standalone 3516 (obsolete) | `rtl_base_filelist.f`, `usb_ip_3511_filelist.f`, `usb_ip_3515_filelist.f`, `usb_ip_3516_filelist.f` | `usb_verilog_top_filelist.f` |

Use separate build output/library directories per source set. Both sets include the same post-sync recovery arbiter source; the compound structure additionally qualifies Recovery for Device 0 and inserts the arbiter between the shared synchronizer and DMA, and its SystemVerilog wrapper connects the Combo Recovery aperture to `usb_ocp_recovery_top`.

VHDL packages/entities/configurations reference `work` (the current compilation library, whatever it's named — e.g. `rtl` or `usb_lib`). The `.f` files bind that library via `-work <library>`.

## Filelist Files

`src/cfg/*.f` files control what gets compiled into which library. When adding new VHDL source files, they must be added to the appropriate `.f` file with the correct `-work <library>` directive:

- `usb_ip_hub_composite_device.f` → compound Hub + composite-device VHDL build (primary target); keep in sync when adding/removing hub sources
- `usb_compound_verilog_filelist.f` → compound SystemVerilog build (AXI-to-AHB converters, decoder, Recovery, `ip_xxx_3511_hs_mem_compound_wrapper.sv`)
- `usb_lib_filelist.f` → `usb_lib` (shared packages, entities, RTL modules; obsolete 3516 path)
- `usb_ip_3511_filelist.f` → `lib_usb_ip_3511` (obsolete 3516 path)
- `usb_ip_3515_filelist.f` → `lib_usb_ip_3515` (obsolete 3516 path)
- `usb_ip_3516_filelist.f` → `lib_usb_ip_3516` (obsolete 3516 path)
- `usb_verilog_top_filelist.f` → Verilog wrapper (obsolete 3516 path, compiled into `work`)

## Register Definitions

`systemrdl/usb_ocp_recovery_reg.rdl` is the only RDL source that generates real, checked-in RTL for the compound design (see "SystemRDL validation and generation" above). `systemrdl/usbhsd.rdl` / `usbhsh.rdl` and the legacy XML `systemrdl/usbhsd.regs` / `usbhsh.regs` document the (obsolete, single-device) USB device/host controller register maps and are not wired into the compound build.

## Reference Documentation

- `docs/USB2_Programmers_Guide.md` — software programming requirements for the compound device (Hub + USBD0 + USBD1): enumeration, endpoint-list init, disconnect/reconnect, reset, hitless firmware update, and recovery. Primary reference for the compound design.
- `docs/Usb_Integration_Guide.pdf` — integration methodology, port descriptions, timing, and configuration guidance for the obsolete `ip_xxx_3516_hs_mem` IP; background reading only, not a description of the compound design.
- Revision history at the top of `ip_xxx_3511_hs_mem_compound_wrapper.sv` is the most reliable source for how/why the compound design's AXI/AHB/Recovery wiring evolved (e.g. the hub descriptor store's migration from external SRAM to an internal flip-flop array).

## Rules and Constraints

NEVER run any git commands that will modify the repository (git commit, git reset, git checkout, etc).
You are allowed to run git commands that review the repository (git log, git diff, git config --get, etc).
