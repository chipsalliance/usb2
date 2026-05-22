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

#nmodi
set_units -time ps

###############################################################################
# IP_3528 Clock constraints
#           ahb_clk    = 480 MHz (400 MHz Over constrained by 20%)
#           usb_clk    =  72 MHz (60 MHz Over constrained by 20%)
###############################################################################

set AHB_CLK_IN_PERIOD [expr 1000 * 2.084]   
set AHB_CLK_IN_SKEW [expr 1000 * 0.25]

set USB_CLK_IN_PERIOD [expr 1000 * 13.88]
set USB_CLK_IN_SKEW [expr 1000 * 0.25]

## ahb clock at 480MHz

create_clock -name ahb_clk_dev -period $AHB_CLK_IN_PERIOD -waveform [list 0 [expr 0.5 * $AHB_CLK_IN_PERIOD]] [get_ports {dev_ahbs_hclk}]
set_clock_uncertainty $AHB_CLK_IN_SKEW [get_clocks {ahb_clk_dev}]

create_clock -name ahb_clk_host -period $AHB_CLK_IN_PERIOD -waveform [list 0 [expr 0.5 * $AHB_CLK_IN_PERIOD]] [get_ports {host_ahbs_hclk}]
set_clock_uncertainty $AHB_CLK_IN_SKEW [get_clocks {ahb_clk_host}]

create_clock -name ahb_clk_dma -period $AHB_CLK_IN_PERIOD -waveform [list 0 [expr 0.5 * $AHB_CLK_IN_PERIOD]] [get_ports {ahbs_dma_hclk}]
set_clock_uncertainty $AHB_CLK_IN_SKEW [get_clocks {ahb_clk_dma}]

## usb_clk derived from SMS PHY clk60 -- utmi_clk, ulpi_clk (60MHz)

create_clock -name utmi_clk -period $USB_CLK_IN_PERIOD -waveform [list 0 [expr 0.5 * $USB_CLK_IN_PERIOD]] [get_ports {utmi_clk}]
set_clock_uncertainty $USB_CLK_IN_SKEW [get_clocks {utmi_clk}]

create_clock -name ulpi_clk -period $USB_CLK_IN_PERIOD -waveform [list 0 [expr 0.5 * $USB_CLK_IN_PERIOD]] [get_ports {ulpi_clk}]
set_clock_uncertainty $USB_CLK_IN_SKEW [get_clocks {ulpi_clk}]

###############################################################################
#Collecting all the input ports excluding clocks in "input_port_list_exclude_clk"
###############################################################################

set input_port_list_exclude_clk [remove_from_collection [all_inputs] [get_ports {dev_ahbs_hclk host_ahbs_hclk ahbs_dma_hclk utmi_clk ulpi_clk}]]

#Setting the input trans 
###############################################################################
set_input_transition 250 $input_port_list_exclude_clk
set_clock_transition 100 [get_clocks *]
###############################################################################

#Provide "set_load" on outputs 
###############################################################################
set_load 4 [ all_outputs ]
###############################################################################

#IO constr
set_input_delay -max [expr 0.5 * $AHB_CLK_IN_PERIOD] -clock [get_clocks {ahb_clk_dev}] [get_ports $input_port_list_exclude_clk]
set_input_delay -max [expr 0.5 * $AHB_CLK_IN_PERIOD] -clock [get_clocks {utmi_clk}] [get_ports $input_port_list_exclude_clk]
set_input_delay -max [expr 0.5 * $AHB_CLK_IN_PERIOD] -clock [get_clocks {ulpi_clk}] [get_ports $input_port_list_exclude_clk]

set_output_delay -max [expr 0.5 * $AHB_CLK_IN_PERIOD] -clock [get_clocks {ahb_clk_dev}] [get_ports [all_outputs]]
set_output_delay -max [expr 0.5 * $AHB_CLK_IN_PERIOD] -clock [get_clocks {utmi_clk}] [get_ports [all_outputs]]
set_output_delay -max [expr 0.5 * $AHB_CLK_IN_PERIOD] -clock [get_clocks {ulpi_clk}] [get_ports [all_outputs]]
###############################################################################
#clock grouping
#nmodi: I asked to Nagesh
#utmi_clk & ulpi_clk  are they synchronous with each other ?
#How they are related with 3 ahb_clk ?

#nmodi: Nagesh replied
#it's only one of the two interfaces that will be selected - not both. so mutually exclusive.
#AHB and UTMI-PHY clks are  asynchronous

set_clock_groups -name func_clks_grp -async \
-group {ahb_clk_dev ahb_clk_host ahb_clk_dma} \
-group {utmi_clk ulpi_clk}

set_clock_groups -name usb_phy_exc_grp -physically_exclusive \
 -group "utmi_clk" \
 -group "ulpi_clk"

