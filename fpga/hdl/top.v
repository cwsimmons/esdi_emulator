
/* 

    Copyright 2025 Christopher Simmons

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the Free
  Software Foundation, either version 2 of the License, or (at your option)
  any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <https://www.gnu.org/licenses/>.

*/

module top(
    input [3:0] esdi_head_select,
    input [2:0] esdi_drive_select,

    input esdi_transfer_req,
    input esdi_command_data,
    output esdi_transfer_ack,
    output esdi_confstat_data,
    output esdi_attention,
    output esdi_ready,

    output esdi_index_gated,
    output esdi_sector_gated,

    output esdi_index_ungated_A,
    output esdi_sector_ungated_A,
    output esdi_command_complete_A,
    output esdi_drive_selected_A,
    input esdi_address_mark_enable_A,

    output esdi_index_ungated_B,
    output esdi_sector_ungated_B,
    output esdi_command_complete_B,
    output esdi_drive_selected_B,
    input esdi_address_mark_enable_B,

    input esdi_read_gate,
    input esdi_write_gate,

    output esdi_read_clock_A,
    output esdi_read_data_A,
    input esdi_write_clock_A,
    input esdi_write_data_A,

    output esdi_read_clock_B,
    output esdi_read_data_B,
    input esdi_write_clock_B,
    input esdi_write_data_B

);

    assign esdi_index_gated = esdi_drive_selected_A && esdi_index_ungated_A;
    assign esdi_sector_gated = esdi_drive_selected_A && esdi_sector_ungated_A;

    design_1 design_1_i(


        .esdi_attention             (esdi_attention),
        .esdi_command_complete      (esdi_command_complete_A),
        .esdi_command_data          (!esdi_command_data),
        .esdi_confstat_data         (esdi_confstat_data),
        .esdi_drive_select          (~esdi_drive_select),
        .esdi_drive_selected        (esdi_drive_selected_A),
        .esdi_head_select           (~esdi_head_select),
        .esdi_index                 (esdi_index_ungated_A),
        .esdi_read_clock            (esdi_read_clock_A),
        .esdi_read_data             (esdi_read_data_A),
        .esdi_read_gate             (esdi_read_gate),
        .esdi_ready                 (esdi_ready),
        .esdi_sector                (esdi_sector_ungated_A),
        .esdi_transfer_ack          (esdi_transfer_ack),
        .esdi_transfer_req          (!esdi_transfer_req),
        .esdi_write_gate            (esdi_write_gate),
        .esdi_write_clock           (esdi_write_clock_A),
        .esdi_write_data            (esdi_write_data_A)
    );

endmodule
