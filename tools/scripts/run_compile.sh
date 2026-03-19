#Set the working directory
setenv USB_COMPILE_DIR `pwd`
setenv USB_CFG_DIR ${USB_COMPILE_DIR}/../../src/cfg
setenv USB_ROOT ${USB_COMPILE_DIR}/../../src

#Create the lib directories if not present 
set dirs = ( usb_lib lib_usb_ip_3511 lib_usb_ip_3515 lib_usb_ip_3516)

foreach d ( $dirs )
    if ( ! -d "$d" ) then
        echo "Directory $d does not exist. Creating..."
        mkdir -p "$d"
    else
        echo "Directory $d already exists."
    endif
end

#Map the lib to the lib directories
set FILE = "synopsys_sim.setup"

# Check if file does not exist
if ( ! -f "$FILE" ) then
    echo "File $FILE does not exist. Creating and adding 4 lines..."

    cat > "$FILE" << EOF
usb_lib : \$USB_COMPILE_DIR/usb_lib
lib_usb_ip_3511 : \$USB_COMPILE_DIR/lib_usb_ip_3511
lib_usb_ip_3515 : \$USB_COMPILE_DIR/lib_usb_ip_3515
lib_usb_ip_3516 : \$USB_COMPILE_DIR/lib_usb_ip_3516
work : \$USB_COMPILE_DIR/work
EOF

chmod +x $FILE

else
    echo "File $FILE already exists."
endif

#Analyze the vhdl usb files
vhdlan -full64 -f ${USB_CFG_DIR}/usb_lib_filelist.f -kdb
vhdlan -full64 -f ${USB_CFG_DIR}/usb_ip_3511_filelist.f -kdb
vhdlan -full64 -f ${USB_CFG_DIR}/usb_ip_3515_filelist.f -kdb
vhdlan -full64 -f ${USB_CFG_DIR}/usb_ip_3516_filelist.f -kdb

#Analyze the verilog top usb wrapper
vlogan -full64 -sverilog -f ${USB_CFG_DIR}/usb_verilog_top_filelist.f -kdb

#Run elaboration
vcs -full64 work.ip_xxx_3516_hs_mem_wrapper -debug_access+all -kdb -l ${USB_COMPILE_DIR}/elab.log

#Run the simulation
./simv

