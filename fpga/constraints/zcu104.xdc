
# Copyright 2024 Christopher Simmons

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

##                                                                               FMC Net Name        Original Function
## FMC Row H
set_property PACKAGE_PIN J16      [get_ports "esdi_transfer_ack"];              # FMC_LPC_LA07_P    esdi_head_select[2]         Output      4
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_transfer_ack"];              # FMC_LPC_LA07_P
set_property PACKAGE_PIN J15      [get_ports "esdi_sector"];                    # FMC_LPC_LA07_N    esdi_head_select[0]         Output      14
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_sector"];                    # FMC_LPC_LA07_N    
set_property PACKAGE_PIN A13      [get_ports "esdi_ready"];                     # FMC_LPC_LA11_P    esdi_transfer_req           Output      24
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_ready"];                     # FMC_LPC_LA11_P
set_property PACKAGE_PIN A12      [get_ports "esdi_command_complete"];          # FMC_LPC_LA11_N    esdi_drive_select[1]        Output      28
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_command_complete"];          # FMC_LPC_LA11_N
set_property PACKAGE_PIN D16      [get_ports "esdi_confstat_data"];             # FMC_LPC_LA15_P    esdi_read_gate              Output      32
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_confstat_data"];             # FMC_LPC_LA15_P
set_property PACKAGE_PIN C16      [get_ports "esdi_attention"];                 # FMC_LPC_LA15_N    esdi_address_mark_enable    Output      J2,4
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_attention"];                 # FMC_LPC_LA15_N
set_property PACKAGE_PIN D12      [get_ports "esdi_read_clock"];                # FMC_LPC_LA19_P    esdi_write_clock            Output
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_clock"];                # FMC_LPC_LA19_P
set_property PACKAGE_PIN B10      [get_ports "esdi_read_data"];                 # FMC_LPC_LA21_P    esdi_write_data             Output
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_data"];                 # FMC_LPC_LA21_P
set_property PACKAGE_PIN B6       [get_ports "esdi_head_select[2]"];            # FMC_LPC_LA24_P    esdi_transfer_ack           Input       10
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[2]"];            # FMC_LPC_LA24_P
set_property PACKAGE_PIN A6       [get_ports "esdi_head_select[0]"];            # FMC_LPC_LA24_N    esdi_sector                 Input       16
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[0]"];            # FMC_LPC_LA24_N
set_property PACKAGE_PIN M13      [get_ports "esdi_transfer_req"];              # FMC_LPC_LA28_P    esdi_ready                  Input       22
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_transfer_req"];              # FMC_LPC_LA28_P
set_property PACKAGE_PIN L13      [get_ports "esdi_read_gate"];                 # FMC_LPC_LA28_N    esdi_command_complete       Input       J2,3
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_read_gate"];                 # FMC_LPC_LA28_N
set_property PACKAGE_PIN E9       [get_ports "esdi_write_clock"];               # FMC_LPC_LA30_P    esdi_read_clock             Input
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_clock"];               # FMC_LPC_LA30_P
set_property PACKAGE_PIN F8       [get_ports "esdi_write_data"];                # FMC_LPC_LA32_P    esdi_read_data              Input
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_data"];                # FMC_LPC_LA32_P
## FMC Row G
set_property PACKAGE_PIN E18      [get_ports "esdi_index"];                     # FMC_LPC_LA08_P    esdi_head_select[3]         Output      2
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_index"];                     # FMC_LPC_LA08_P
set_property PACKAGE_PIN E17      [get_ports "esdi_drive_selected"];            # FMC_LPC_LA08_N    esdi_write_gate             Output      6
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_drive_selected"];            # FMC_LPC_LA08_N
set_property PACKAGE_PIN G18      [get_ports "esdi_sector2"];                   # FMC_LPC_LA12_P    esdi_head_select[1]         Output      18
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_sector2"];                   # FMC_LPC_LA12_P
set_property PACKAGE_PIN F18      [get_ports "esdi_index2"];                    # FMC_LPC_LA12_N    esdi_drive_select[0]        Output      26
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_index2"];                    # FMC_LPC_LA12_N
# set_property PACKAGE_PIN D17      [get_ports ""];                               # FMC_LPC_LA16_P    esdi_drive_select[2]        Output      30
# set_property IOSTANDARD  LVCMOS12 [get_ports ""];                               # FMC_LPC_LA16_P
# set_property PACKAGE_PIN C17      [get_ports ""];                               # FMC_LPC_LA16_N    esdi_command_data           Output      34
# set_property IOSTANDARD  LVCMOS12 [get_ports ""];                               # FMC_LPC_LA16_N
set_property PACKAGE_PIN C7       [get_ports "esdi_address_mark_enable"];       # FMC_LPC_LA25_P    esdi_confstat_data          Input       8
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_address_mark_enable"];       # FMC_LPC_LA25_P
set_property PACKAGE_PIN C6       [get_ports "esdi_head_select[3]"];            # FMC_LPC_LA25_N    esdi_attention              Input       12
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[3]"];            # FMC_LPC_LA25_N
set_property PACKAGE_PIN K10      [get_ports "esdi_write_gate"];                # FMC_LPC_LA29_P    esdi_index                  Input       20
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_write_gate"];                # FMC_LPC_LA29_P
set_property PACKAGE_PIN J10      [get_ports "esdi_head_select[1]"];            # FMC_LPC_LA29_N    esdi_drive_selected         Input       J2,1
set_property IOSTANDARD  LVCMOS12 [get_ports "esdi_head_select[1]"];            # FMC_LPC_LA29_N

## PMOD A
set_property PACKAGE_PIN G8       [get_ports "esdi_drive_select[0]"];           # PMOD0_0
set_property IOSTANDARD LVCMOS33  [get_ports "esdi_drive_select[0]"];           # PMOD0_0
set_property PACKAGE_PIN H8       [get_ports "esdi_drive_select[1]"];           # PMOD0_1
set_property IOSTANDARD LVCMOS33  [get_ports "esdi_drive_select[1]"];           # PMOD0_1
set_property PACKAGE_PIN G7       [get_ports "esdi_drive_select[2]"];           # PMOD0_2
set_property IOSTANDARD LVCMOS33  [get_ports "esdi_drive_select[2]"];           # PMOD0_2
set_property PACKAGE_PIN H7       [get_ports "esdi_command_data"];              # PMOD0_3
set_property IOSTANDARD LVCMOS33  [get_ports "esdi_command_data"];              # PMOD0_3