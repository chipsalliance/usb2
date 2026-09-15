--  SPDX-License-Identifier: Apache-2.0
-- 
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
-- 
--  http://www.apache.org/licenses/LICENSE-2.0
-- 
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
-- 
-- ----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.usb_general_subcmp_pkg.all;
use work.usb_configuration_subcmp_pkg.all;
use work.usb_subcmp_pkg.all;

configuration ip_xxx_3511_hs_mem_compound_structure_cfg of ip_xxx_3511_hs_mem_compound is
  for structure
    for usb_pie_1: usb_pie
      use entity work.usb_pie(rtl);
    end for;
    for usb_synchronizer_1: usb_synchronizer
      use entity work.usb_synchronizer(rtl);
    end for;
    for usb_reg_if_1 : usb_reg_if
      use entity work.usb_reg_if(rtl);
    end for;
    for usb_reg_if_2 : usb_reg_if
      use entity work.usb_reg_if(rtl);
    end for;
    for usb_dma_1 : usb_dma
      use entity work.usb_dma(rtl);
    end for;
    for ahb_dma_slave_1 : ahb_dma_slave
      use entity work.ahb_dma_slave(rtl);
    end for;
    for ahb_dma_slave_2 : ahb_dma_slave
      use entity work.ahb_dma_slave(rtl);
    end for;
    for usb_ahb_slave_1 : usb_ahb_slave
      use entity work.usb_ahb_slave(rtl);
    end for;
    for usb_ahb_slave_2 : usb_ahb_slave
      use entity work.usb_ahb_slave(rtl);
    end for;
    for usb_ahb_slave_0 : usb_ahb_slave
      use entity work.usb_ahb_slave(rtl);
    end for;
    for usb_ep0_hub_descr_1 : usb_ep0_hub_descr
      use entity work.usb_ep0_hub_descr(rtl);
    end for;
    for usb_mux_1 : usb_mux
      use entity work.usb_mux(rtl);
    end for;
    for usb_ep0_handler_1 : usb_ep0_handler
      use entity work.usb_ep0_handler(rtl);
    end for;
    for usb_ep_config_handler_1 : usb_ep_config_handler
      use entity work.usb_ep_config_handler(rtl);
    end for;
    for usb_app_hw_hub_1 : usb_app_hw_hub
      use entity work.usb_app_hw_hub(rtl);
    end for;
  end for;
end ip_xxx_3511_hs_mem_compound_structure_cfg;

