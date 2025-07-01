
/* 

    Copyright 2024 Christopher Simmons

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

module fifo_registered #(
    parameter WIDTH_IN_BYTES = 4,
    parameter DEPTH_EXP = 16,
    parameter TID_WIDTH = 8,
    parameter WRITE_WHEN_FULL = 1
) (
    input clk,
    input reset_n,

    input in_tvalid,
    output in_tready,
    input [8*WIDTH_IN_BYTES-1:0] in_tdata,
    input [WIDTH_IN_BYTES-1:0] in_tkeep,
    input in_tlast,
    input [TID_WIDTH-1:0] in_tid,

    output reg out_tvalid,
    input out_tready,
    output reg [8*WIDTH_IN_BYTES-1:0] out_tdata,
    output reg [WIDTH_IN_BYTES-1:0] out_tkeep,
    output reg out_tlast,
    output reg [TID_WIDTH-1:0] out_tid,
    
    output [DEPTH_EXP:0] num_free,
    output reg [DEPTH_EXP:0] num_used
);

    reg [DEPTH_EXP:0] next_num_used;
    reg [DEPTH_EXP-1:0] newest;
    reg [DEPTH_EXP-1:0] oldest;

    reg [WIDTH_IN_BYTES*8-1:0] storage [0:2**DEPTH_EXP-1];
    reg tlast [0:2**DEPTH_EXP-1];
    reg [WIDTH_IN_BYTES-1:0] tkeep [0:2**DEPTH_EXP-1];
    reg [TID_WIDTH-1:0] tid [0:2**DEPTH_EXP-1];

    assign num_free = 2**DEPTH_EXP - num_used;

    assign in_tready = !num_used[DEPTH_EXP] || WRITE_WHEN_FULL;

    always @(posedge clk)
    begin

        if (!reset_n)
        begin
            oldest <= 0;
            newest <= 0;
            out_tvalid <= 0;
            num_used <= 0;
        end
        else
        begin
            next_num_used = num_used;

            if (out_tready && out_tvalid)
            begin
                out_tvalid <= 0;
                next_num_used = next_num_used - 1;
            end

            if (in_tvalid && in_tready)
            begin
                storage[newest] <= in_tdata;
                tlast[newest] <= in_tlast;
                tkeep[newest] <= in_tkeep;
                tid[newest] <= in_tid;
                newest <= newest + 1;

                if (num_used[DEPTH_EXP])
                    oldest <= oldest + 1;
                
                if (!next_num_used[DEPTH_EXP])
                    next_num_used = next_num_used + 1;

            end

            if (!out_tvalid || out_tready)
            begin
                if (newest != oldest)
                begin
                    out_tvalid <= 1;
                    out_tdata <= storage[oldest];
                    out_tlast <= tlast[oldest];
                    out_tkeep <= tkeep[oldest];
                    out_tid <= tid[oldest];
                    oldest <= oldest + 1;

                end
            end

            num_used <= next_num_used;
        end
    end

endmodule
