# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#Set the working directory
setenv USB_COMPILE_DIR `pwd`
setenv USB_CFG_DIR ${USB_COMPILE_DIR}/../../src/cfg
setenv USB_ROOT ${USB_COMPILE_DIR}/../../src

#Create the lib directories if not present 
set dirs = ( rtl )

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
    echo "File $FILE does not exist. Creating and adding 2 lines..."

    cat > "$FILE" << EOF
rtl : \$USB_COMPILE_DIR/rtl
work : \$USB_COMPILE_DIR/work
EOF

chmod +x $FILE

else
    echo "File $FILE already exists."
endif

#Analyze the vhdl usb files
vhdlan -full64 -f ${USB_CFG_DIR}/rtl_base_filelist.f -kdb -l ${USB_COMPILE_DIR}/analyze_rtl_base.log
vhdlan -full64 -f ${USB_CFG_DIR}/usb_ip_3511_filelist.f -kdb -l ${USB_COMPILE_DIR}/analyze_usb_ip_3511.log
vhdlan -full64 -f ${USB_CFG_DIR}/usb_ip_3515_filelist.f -kdb -l ${USB_COMPILE_DIR}/analyze_usb_ip_3515.log
vhdlan -full64 -f ${USB_CFG_DIR}/usb_ip_3516_filelist.f -kdb -l ${USB_COMPILE_DIR}/analyze_usb_ip_3516.log

#Analyze the verilog top usb wrapper
vlogan -full64 -sverilog -f ${USB_CFG_DIR}/usb_verilog_top_filelist.f -kdb -l ${USB_COMPILE_DIR}/analyze_usb_verilog_top.log

#Run elaboration
vcs -full64 rtl.usb_top_tb -timescale=1ns/1ps -debug_access+all -kdb -l ${USB_COMPILE_DIR}/elab.log

#Run the simulation
set MY_GREEN    = '\e[32m'
set MY_CLR      = '\e[m'
echo "${MY_GREEN}Running simulation${MY_CLR}"
./simv -l ${USB_COMPILE_DIR}/sim.log -ucli -i ucli_script +fsdb+all=on

