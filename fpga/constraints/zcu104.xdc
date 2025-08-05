
# Copyright 2025 Christopher Simmons

# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 2 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

set_property PACKAGE_PIN F23 [get_ports {clk125_p_i}]
set_property PACKAGE_PIN E23 [get_ports {clk125_n_i}]
set_property IOSTANDARD LVDS [get_ports "clk125_p_i"] ;
set_property IOSTANDARD LVDS [get_ports "clk125_n_i"] ;
# 125MHz is 1/8ns
# create_clock -name clk125 -period 8.000 [get_ports {clk125_p_i}]

# set_property PACKAGE_PIN D5       [get_ports "leds[0]"];
# set_property IOSTANDARD LVCMOS33  [get_ports "leds[0]"];
# set_property PACKAGE_PIN D6       [get_ports "leds[1]"];
# set_property IOSTANDARD LVCMOS33  [get_ports "leds[1]"];
# set_property PACKAGE_PIN A5       [get_ports "leds[2]"];
# set_property IOSTANDARD LVCMOS33  [get_ports "leds[2]"];
# set_property PACKAGE_PIN B5       [get_ports "leds[3]"];
# set_property IOSTANDARD LVCMOS33  [get_ports "leds[3]"];


## Inputs
set_property PACKAGE_PIN F17      [get_ports "esdi_head_select[3]"];              # FMC_LPC_LA00_P
set_property PACKAGE_PIN L20      [get_ports "esdi_head_select[2]"];              # FMC_LPC_LA02_P
set_property PACKAGE_PIN F16      [get_ports "esdi_write_gate"];                  # FMC_LPC_LA00_N
set_property PACKAGE_PIN K20      [get_ports "esdi_head_select[0]"];              # FMC_LPC_LA02_N
set_property PACKAGE_PIN K19      [get_ports "esdi_head_select[1]"];              # FMC_LPC_LA03_P
set_property PACKAGE_PIN L17      [get_ports "esdi_transfer_req"];                # FMC_LPC_LA04_P
set_property PACKAGE_PIN K18      [get_ports "esdi_drive_select[0]"];             # FMC_LPC_LA03_N
set_property PACKAGE_PIN L16      [get_ports "esdi_drive_select[1]"];             # FMC_LPC_LA04_N
set_property PACKAGE_PIN E18      [get_ports "esdi_drive_select[2]"];             # FMC_LPC_LA08_P
set_property PACKAGE_PIN J16      [get_ports "esdi_read_gate"];                   # FMC_LPC_LA07_P
set_property PACKAGE_PIN E17      [get_ports "esdi_command_data"];                # FMC_LPC_LA08_N
set_property PACKAGE_PIN J15      [get_ports "esdi_address_mark_enable_A"];       # FMC_LPC_LA07_N
set_property PACKAGE_PIN G18      [get_ports "esdi_address_mark_enable_B"];       # FMC_LPC_LA12_P

set_property PACKAGE_PIN A13      [get_ports "esdi_write_data_A"];                # FMC_LPC_LA11_P
set_property PACKAGE_PIN D17      [get_ports "esdi_write_clock_A"];               # FMC_LPC_LA16_P
set_property PACKAGE_PIN D16      [get_ports "esdi_write_data_B"];                # FMC_LPC_LA15_P
set_property PACKAGE_PIN F12      [get_ports "esdi_write_clock_B"];               # FMC_LPC_LA20_P

## Outputs
set_property PACKAGE_PIN D12      [get_ports "esdi_confstat_data"];               # FMC_LPC_LA19_P
set_property PACKAGE_PIN C11      [get_ports "esdi_transfer_ack"];                # FMC_LPC_LA19_N
set_property PACKAGE_PIN H13      [get_ports "esdi_attention"];                   # FMC_LPC_LA22_P
set_property PACKAGE_PIN B10      [get_ports "esdi_sector_gated"];                # FMC_LPC_LA21_P
set_property PACKAGE_PIN H12      [get_ports "esdi_index_gated"];                 # FMC_LPC_LA22_N
set_property PACKAGE_PIN A10      [get_ports "esdi_ready"];                       # FMC_LPC_LA21_N
set_property PACKAGE_PIN C7       [get_ports "esdi_drive_selected_A"];            # FMC_LPC_LA25_P
set_property PACKAGE_PIN B6       [get_ports "esdi_sector_ungated_A"];            # FMC_LPC_LA24_P
set_property PACKAGE_PIN C6       [get_ports "esdi_command_complete_A"];          # FMC_LPC_LA25_N
set_property PACKAGE_PIN A6       [get_ports "esdi_index_ungated_A"];             # FMC_LPC_LA24_N
set_property PACKAGE_PIN K10      [get_ports "esdi_index_ungated_B"];             # FMC_LPC_LA29_P
set_property PACKAGE_PIN M13      [get_ports "esdi_drive_selected_B"];            # FMC_LPC_LA28_P
set_property PACKAGE_PIN J10      [get_ports "esdi_sector_ungated_B"];            # FMC_LPC_LA29_N
set_property PACKAGE_PIN L13      [get_ports "esdi_command_complete_B"];          # FMC_LPC_LA28_N

set_property PACKAGE_PIN F7       [get_ports "esdi_read_data_A"];                 # FMC_LPC_LA31_P
set_property PACKAGE_PIN E9       [get_ports "esdi_read_clock_A"];                # FMC_LPC_LA30_P
set_property PACKAGE_PIN C9       [get_ports "esdi_read_data_B"];                 # FMC_LPC_LA33_P
set_property PACKAGE_PIN F8       [get_ports "esdi_read_clock_B"];                # FMC_LPC_LA32_P

##
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[3]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[2]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_gate"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[0]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[1]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_transfer_req"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_drive_select[0]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_drive_select[1]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_drive_select[2]"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_gate"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_command_data"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_address_mark_enable_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_address_mark_enable_B"];

set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_data_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_clock_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_data_B"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_clock_B"];

set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_confstat_data"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_transfer_ack"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_attention"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_sector_gated"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_index_gated"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_ready"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_drive_selected_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_sector_ungated_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_command_complete_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_index_ungated_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_index_ungated_B"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_drive_selected_B"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_sector_ungated_B"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_command_complete_B"];

set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_data_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_clock_A"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_data_B"];
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_clock_B"];