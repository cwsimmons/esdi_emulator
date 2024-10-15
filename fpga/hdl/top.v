
module top(

    input clk125_p_i,
    input clk125_n_i,

    input reset,

    input esdi_transfer_req,
    input esdi_command_data,
    output esdi_transfer_ack,
    output esdi_confstat_data,
    output esdi_index,
    output esdi_sector,
    output esdi_index2,
    output esdi_sector2,
    input esdi_read_gate,
    output esdi_read_clock,
    output esdi_read_data,
    output esdi_attention,
    output esdi_ready,
    output esdi_command_complete,
    output esdi_drive_selected,
    input [3:0] esdi_head_select,
    input [2:0] esdi_drive_select,
    input esdi_address_mark_enable,
    input esdi_write_gate,
    input esdi_write_clock,
    input esdi_write_data

);

    assign esdi_index = esdi_drive_selected && esdi_index2;
    assign esdi_sector = esdi_drive_selected && esdi_sector2;

    design_1 design_1_i(
        .CLK_IN_clk_p               (clk125_p_i),
        .CLK_IN_clk_n               (clk125_n_i),

        .reset                      (reset),

        .esdi_attention             (esdi_attention),
        .esdi_command_complete      (esdi_command_complete),
        .esdi_command_data          (!esdi_command_data),
        .esdi_confstat_data         (esdi_confstat_data),
        .esdi_drive_select          (~esdi_drive_select),
        .esdi_drive_selected        (esdi_drive_selected),
        .esdi_head_select           (~esdi_head_select),
        .esdi_index                 (esdi_index2),
        .esdi_ready                 (esdi_ready),
        .esdi_sector                (esdi_sector2),
        .esdi_transfer_ack          (esdi_transfer_ack),
        .esdi_transfer_req          (!esdi_transfer_req)
    );

endmodule
