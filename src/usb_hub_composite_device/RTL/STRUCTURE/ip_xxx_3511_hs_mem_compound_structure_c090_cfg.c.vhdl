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

library usb_lib;
use usb_lib.usb_general_subcmp_pkg.all;
use usb_lib.usb_configuration_subcmp_pkg.all;
use usb_lib.usb_subcmp_pkg.all;

configuration ip_xxx_3511_hs_mem_compound_c090_cfg of ip_xxx_3511_hs_mem_compound is
  for structure
    for usb_pie_1: usb_pie
      use entity usb_lib.usb_pie(rtl);
    end for;
    for usb_synchronizer_1: usb_synchronizer
      use entity usb_lib.usb_synchronizer(rtl);
    end for;
    for usb_reg_if_1 : usb_reg_if
      use entity usb_lib.usb_reg_if(rtl);
    end for;
    for usb_dma_1 : usb_dma
      use entity usb_lib.usb_dma(rtl);
    end for;
    for ahb_dma_slave_1 : ahb_dma_slave
      use entity usb_lib.ahb_dma_slave(rtl);
    end for;
    for usb_ahb_slave_1 : usb_ahb_slave
      use entity usb_lib.usb_ahb_slave(rtl);
    end for;
    --<<<< LAB rename this without full speed confusing
    for usb_fs_mux_1 : usb_fs_mux
      use entity usb_lib.usb_fs_mux(rtl);
    end for;
    for usb_ep0_handler_1 : usb_ep0_handler
      use entity usb_lib.usb_ep0_handler(rtl);
    end for;
    for usb_ep_config_handler_1 : usb_ep_config_handler
      use entity usb_lib.usb_ep_config_handler(rtl);
    end for;
    for usb_app_hw_hub_1 : usb_app_hw_hub
      use entity usb_lib.usb_app_hw_hub(rtl);
    end for;
  end for;
end ip_xxx_3511_hs_mem_compound_c090_cfg;

