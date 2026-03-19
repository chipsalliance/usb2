# usb

This is the USB2.0 Host + device controller IP
Language : vhdl + verilog
Top level wrapper : ip_xxx_3516_hs_mem_wrapper
To compile : ./run_compile

|-- docs                                                                   #Documentation
|   |-- USB2.0_IP_Integration_guide.pdf
|-- src
|   |-- cfg                                                                #Filelists used for compilation
|   |   |-- usb_ip_3511_filelist.f
|   |   |-- usb_ip_3515_filelist.f
|   |   |-- usb_ip_3516_filelist.f
|   |   |-- usb_lib_filelist.f
|   |   `-- usb_verilog_top_filelist.f
|   |-- integration                                                        #Top level verilog wrapper
|   |   `-- rtl
|   |       `-- ip_xxx_3516_hs_mem_wrapper.v
|   |-- ip_xxx_3511                                                        #component library
|   |   |-- INTERFACE                                                 
|   |   |   |-- ahb_dma_slave_cmp_pkg.p.vhdl
|   |   |   |-- ip_xxx_3511.e.vhdl
|   |   |   |-- ip_xxx_3511_cmp_pkg.p.vhdl
|   |   |   |-- usb_cfg_pkg.p.vhdl
|   |   |   |-- usb_configuration_app_cmsis_dap_jtag_pkg.p.vhdl
|   |   |   |-- usb_configuration_subcmp_pkg.p.vhdl
|   |   |   |-- usb_ep_config_hub_cmsis_dap_jtag_pkg.p.vhdl
|   |   |   |-- usb_ep_config_pkg.p.vhdl
|   |   |   |-- usb_fs_emb_dev_pkg.p.vhdl
|   |   |   |-- usb_fs_hub_pkg.p.vhdl
|   |   |   |-- usb_general_subcmp_pkg.p.vhdl
|   |   |   `-- usb_subcmp_pkg.p.vhdl
|   |   `-- RTL
|   |       |-- ahb_dma_slave.m.vhdl
|   |       |-- usb_ahb_master.m.vhdl
|   |       |-- usb_ahb_slave.m.vhdl
|   |       |-- usb_clkrec.m.vhdl
|   |       |-- usb_dma.m.vhdl
|   |       |-- usb_host_dma.m.vhdl
|   |       |-- usb_host_pie.m.vhdl
|   |       |-- usb_host_reg_if.m.vhdl
|   |       |-- usb_host_sof_timer.m.vhdl
|   |       |-- usb_host_synchronizer.m.vhdl
|   |       |-- usb_pie.m.vhdl
|   |       |-- usb_reg_if.m.vhdl
|   |       |-- usb_rgen.m.vhdl
|   |       |-- usb_sie.m.vhdl
|   |       |-- usb_sieint.m.vhdl
|   |       |-- usb_synchronizer.m.vhdl
|   |       |-- usb_timers_sf.m.vhdl
|   |       |-- usb_tx_sf_dpdm.m.vhdl
|   |       `-- usb_upstreamled.m.vhdl
|   |-- ip_xxx_3511_hs                                                     #USB device  
|   |   |-- INTERFACE
|   |   |   |-- ip_xxx_3511_hs.e.vhdl
|   |   |   `-- ip_xxx_3511_hs_cmp_pkg.p.vhdl
|   |   `-- STRUCTURE
|   |       `-- ip_xxx_3511_hs_structure.a.vhdl
|   |-- ip_xxx_3515_hs                                                     #USB Host
|   |   |-- INTERFACE
|   |   |   |-- ip_xxx_3515_hs.e.vhdl
|   |   |   `-- ip_xxx_3515_hs_cmp_pkg.p.vhdl
|   |   `-- STRUCTURE
|   |       `-- ip_xxx_3515_hs_structure.a.vhdl
|   `-- ip_xxx_3516_hs_mem                                                 #USB device + host controller 
|       |-- INTERFACE
|       |   |-- ip_xxx_3516_hs_mem.e.vhdl
|       |   `-- ip_xxx_3516_hs_mem_cmp_pkg.p.vhdl
|       `-- STRUCTURE
|           `-- ip_xxx_3516_hs_mem_structure.a.vhdl
|-- systemrdl                                                              #Registers 
|   |-- usbhsd.regs
|   `-- usbhsh.regs
`-- tools
    |-- scripts                                                            #compilation scripts   
    |   |-- run_compile.sh                                                  
    |   `-- synopsys_sim.setup
    `-- sdc                                                                #Synthesis constraints  
        `-- ip_3516_hs_mem.sdc.tcl
