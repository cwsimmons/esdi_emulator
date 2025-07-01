

module labeler #(
    parameter DATA_WIDTH = 8
) (

    input aclk,
    input aresetn,

    input in_tvalid,
    output in_tready,
    input [DATA_WIDTH-1:0] in_tdata,
    input in_tlast,
    input [DATA_WIDTH-1:0] in_tid,
    
    output reg out_tvalid,
    input out_tready,
    output reg [DATA_WIDTH-1:0] out_tdata,
    output reg out_tlast
);

    reg next_beat_is_first;

    assign in_tready = (!out_tvalid || out_tready) && !hold_valid;

    reg hold_valid;
    reg [7:0] hold_data;
    reg hold_last;

    always @(posedge aclk)
    begin
        if (!aresetn)
        begin
            out_tvalid <= 0;
            next_beat_is_first <= 1;
            hold_valid <= 0;
        end
        else
        begin

            if (out_tready)
                out_tvalid <= 0;

            if (in_tready && in_tvalid)
            begin
                if (next_beat_is_first)
                begin
                    out_tvalid <= 1;
                    out_tdata <= in_tid;
                    out_tlast <= 0;

                    hold_valid <= 1;
                    hold_data <= in_tdata;
                    hold_last <= in_tlast;

                    next_beat_is_first <= 0;
                end
                else
                begin
                    out_tvalid <= 1;
                    out_tdata <= in_tdata;
                    out_tlast <= in_tlast;
                end

                if (in_tlast)
                    next_beat_is_first <= 1;

            end

            if (hold_valid && (!out_tvalid || out_tready))
            begin
                out_tvalid <= 1;
                out_tdata <= hold_data;
                out_tlast <= hold_last;
                hold_valid <= 0;
            end
        end
    end

endmodule