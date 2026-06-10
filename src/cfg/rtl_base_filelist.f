-work rtl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_general_subcmp_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_subcmp_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_fs_emb_dev_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_configuration_subcmp_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/ip_xxx_3511.e.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/ip_xxx_3511_cmp_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_cfg_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_configuration_app_cmsis_dap_jtag_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_ep_config_hub_cmsis_dap_jtag_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_ep_config_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/INTERFACE/usb_fs_hub_pkg.p.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_ahb_master.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_ahb_slave.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_clkrec.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_dma.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_host_dma.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_host_pie.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_host_reg_if.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_host_sof_timer.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_host_synchronizer.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_pie.m.vhdl
-- Order requirement (OCP Recovery v1.1 splice, Phase 1c plan D0.B):
--   usb_pie_recovery_arb.e.vhdl declares the entity referenced by the
--   structure splice in ip_xxx_3511_hs_structure.a.vhdl.  The architecture
--   `.m.vhdl` must be compiled into the same library as the entity, AFTER
--   the entity.  Neither file is referenced by usb_pie.m.vhdl, so they
--   could appear anywhere before ip_xxx_3511_hs_structure.a.vhdl
--   (compiled by usb_ip_3511_filelist.f).  Kept directly after usb_pie
--   for readability of compile order in the source tree.
${USB_ROOT}/ip_xxx_3511/RTL/usb_pie_recovery_arb.e.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_pie_recovery_arb.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_reg_if.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_rgen.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_sie.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_sieint.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_synchronizer.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_timers_sf.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_tx_sf_dpdm.m.vhdl
${USB_ROOT}/ip_xxx_3511/RTL/usb_upstreamled.m.vhdl
