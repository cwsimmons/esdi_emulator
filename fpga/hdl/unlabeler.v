

module unlabeler #(
    parameter DATA_WIDTH = 8
) (

    input aclk,
    input aresetn,

    input in_tvalid,
    output in_tready,
    input [DATA_WIDTH-1:0] in_tdata,
    input in_tlast,
    
    output reg out_tvalid,
    input out_tready,
    output reg [DATA_WIDTH-1:0] out_tdata,
    output reg out_tlast,
    output reg [DATA_WIDTH-1:0] out_tid
);

    reg next_beat_is_first;

    assign in_tready = !out_tvalid || out_tready;

    always @(posedge aclk)
    begin
        if (!aresetn)
        begin
            out_tvalid <= 0;
            next_beat_is_first <= 1;
        end
        else
        begin

            if (out_tready)
                out_tvalid <= 0;

            if (in_tready && in_tvalid)
            begin
                if (next_beat_is_first)
                begin
                    out_tid <= in_tdata;
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
        end
    end

endmodule