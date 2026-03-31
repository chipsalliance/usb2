# Copilot Instructions

## Project Overview

USB 2.0 Host + Device Controller IP (NXP). Targets LPC54S60x/LPC5460x microcontrollers. The top-level integration module is `ip_xxx_3516_hs_mem_wrapper` (Verilog), which wraps the primary VHDL IP core (`ip_xxx_3516_hs_mem`), which in turn builds on the base IP (`ip_xxx_3511`).

## Build & Simulation

Uses **Synopsys VCS** (W-2024.09-SP1_Full64). No Makefile — compilation is driven by a shell script:

```sh
cd tools/scripts
./run_compile.sh
```

The script:
1. Creates four compilation libraries: `usb_lib`, `lib_usb_ip_3511`, `lib_usb_ip_3515`, `lib_usb_ip_3516`
2. Compiles VHDL via `vhdlan -full64` using `.f` filelist files in `src/cfg/`
3. Compiles Verilog via `vlogan -sverilog`
4. Elaborates with `vcs`, then runs `./simv`

Environment variable `$USB_COMPILE_DIR` must be set — it's the output directory for compiled libraries (see `tools/scripts/synopsys_sim.setup`).

There are no lint or unit test commands beyond the VCS compilation/simulation flow.

## Architecture

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

**Three clock domains** (defined in `tools/sdc/ip_3516_hs_mem.sdc.tcl`):
- AHB clocks (`ahb_clk_dev`, `ahb_clk_host`, `ahb_clk_dma`) — synchronous group
- USB PHY clocks (`utmi_clk`, `ulpi_clk`) — mutually exclusive, async to AHB

**IP variants** (each has its own `INTERFACE/` + `STRUCTURE/` or `RTL/` subdirs under `src/`):
- `ip_xxx_3511` — base IP (device-mode focus)
- `ip_xxx_3511_hs` — high-speed variant
- `ip_xxx_3515_hs` — alternate high-speed variant
- `ip_xxx_3516_hs_mem` — high-speed + embedded RAM (primary, used by wrapper)

## File Naming Conventions

VHDL files use suffixes that encode their role:

| Suffix | Role |
|--------|------|
| `.p.vhdl` | Package (type/constant declarations) |
| `.e.vhdl` | Entity (port interface) |
| `.m.vhdl` | Module / RTL implementation |
| `.a.vhdl` | Architecture / structural composition |

## Signal Naming Conventions

Port prefixes in the Verilog wrapper and VHDL entities follow a consistent scheme:

| Prefix | Domain |
|--------|--------|
| `dev_` | USB device mode |
| `host_` | USB host mode |
| `ahbs_` / `ahbm_` | AHB slave / master |
| `utmi_` | UTMI PHY interface |
| `ulpi_` | ULPI PHY interface |
| `mem_` | Embedded RAM interface |
| `SIE_`, `PIE_` | Internal component interfaces (uppercase) |

## Key Configuration Parameters

Defined as Verilog parameters in `src/integration/rtl/ip_xxx_3516_hs_mem_wrapper.v` and passed as VHDL generics:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `RAM_ADDRWIDTH` | 9 | Embedded RAM address width |
| `C_NBPHYSEP` | 14 | Number of physical endpoints |
| `C_EPUB` | 32 | Endpoint input buffer size |
| `C_DAUB` | 32 | Data array user buffer size |
| `C_SINGLE_BUFFER_SUPPORTED` | 1 | Enable single-buffer mode |
| `C_DOUBLE_BUFFER_SUPPORTED` | 1 | Enable double-buffer mode |
| `C_ULPI_SUPPORT` | 1 | ULPI PHY support |
| `C_UTMI_SUPPORT` | 1 | UTMI PHY support |

## Filelist Files

`src/cfg/*.f` files control what gets compiled into which library. When adding new VHDL source files, they must be added to the appropriate `.f` file with the correct `-work <library>` directive:

- `usb_lib_filelist.f` → `usb_lib` (shared packages, entities, RTL modules)
- `usb_ip_3511_filelist.f` → `lib_usb_ip_3511`
- `usb_ip_3515_filelist.f` → `lib_usb_ip_3515`
- `usb_ip_3516_filelist.f` → `lib_usb_ip_3516`
- `usb_verilog_top_filelist.f` → Verilog wrapper (compiled into `work`)

## Register Definitions

`systemrdl/usbhsd.regs` and `systemrdl/usbhsh.regs` are XML-based SystemRDL register maps (converted from SVD format) for the USB device and host controllers respectively. These define the register-level interface exposed to software.

## Reference Documentation

`docs/Usb_Integration_Guide.pdf` — integration methodology, port descriptions, timing, and configuration guidance.
