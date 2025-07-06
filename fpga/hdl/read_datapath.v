
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

module read_datapath (
    input csr_aclk,
    input csr_aresetn,

    output trig_out,// output wire trig_out 
    input trig_out_ack,// input wire trig_out_ack 
    input trig_in,// input wire trig_in 
    output trig_in_ack,// output wire trig_in_ack 

    input parallel_aclk,
    input parallel_aresetn,

    input csr_awvalid,
    output csr_awready,
    input [4:0] csr_awaddr,
    input [2:0] csr_awprot,

    input csr_wvalid,
    output csr_wready,
    input [31:0] csr_wdata,
    input [3:0] csr_wstrb,

    output reg csr_bvalid,
    input csr_bready,
    output reg [1:0] csr_bresp,

    input csr_arvalid,
    output csr_arready,
    input [4:0] csr_araddr,
    input [2:0] csr_arprot,

    output reg csr_rvalid,
    input csr_rready,
    output reg [31:0] csr_rdata,
    output reg [1:0] csr_rresp,

    input parallel_tvalid,
    output parallel_tready,
    input [7:0] parallel_tdata,
    input parallel_tlast,
    input [7:0] parallel_tid,

    input [7:0] sector_number,
    input [31:0] cycle_count,

    input esdi_read_gate,
    output esdi_read_data,
    output reg esdi_read_clock,

    output reg read_data_valid,
    output reg esdi_read_data_ungated
);

    reg write_addr_valid;
    reg write_data_valid;
    reg [4:0] write_addr;
    reg [31:0] write_data;

    assign csr_awready = !write_addr_valid;
    assign csr_wready = !write_data_valid;
    assign csr_arready = !csr_rvalid || csr_rready;

    reg [31:0] control_register;

    wire silence = control_register[0];

    reg [6:0] clocks_per_halfbit;

    reg [3:0] esdi_read_gate_shift;
    reg [7:0] clock_counter;

    reg reading;

    reg hold_valid;
    reg [7:0] hold_data;
    reg hold_last;
    reg [7:0] hold_id;

    reg [6:0] shift_reg;
    reg shift_reg_last;

    reg [2:0] bit_count;

    reg underflow;
    reg missed_deadline;

    assign parallel_tready = !hold_valid;
    assign esdi_read_data = esdi_read_data_ungated && !esdi_read_gate_shift[1] && !silence;


    always @(posedge csr_aclk)
    begin

        esdi_read_gate_shift <= {esdi_read_gate, esdi_read_gate_shift[3:1]};

        if (!csr_aresetn)
        begin

            control_register <= 0;
            clocks_per_halfbit <= 5;

            write_addr_valid <= 0;
            write_data_valid <= 0;
            csr_bvalid <= 0;
            csr_rvalid <= 0;

            hold_valid <= 0;
            clock_counter <= 0;
            reading <= 0;
            underflow <= 0;
            missed_deadline <= 0;
            read_data_valid <= 0;

        end
        else
        begin

            read_data_valid <= 0;

            if (parallel_tvalid && parallel_tready)
            begin
                hold_valid <= 1;
                hold_data <= parallel_tdata;
                hold_last <= parallel_tlast;
                hold_id <= parallel_tid;
            end

            if (cycle_count == 0 && hold_valid && hold_id == sector_number)
            begin
                reading <= 1;
                shift_reg_last <= 0;
                bit_count <= 3'b111; // we want an overflow on next increment
            end

            clock_counter <= clock_counter + 1;
            if (clock_counter == (clocks_per_halfbit - 1))
            begin
                esdi_read_clock <= 1;
            end
            else if (clock_counter == ((clocks_per_halfbit << 1) - 1))
            begin

                clock_counter <= 0;

                esdi_read_clock <= 0;

                read_data_valid <= 1;

                if (reading)
                begin
                    bit_count <= bit_count + 1;

                    if (bit_count == 3'b111)
                    begin

                        if (shift_reg_last)
                        begin
                            reading <= 0;
                            esdi_read_data_ungated <= 0;
                        end
                        else
                        begin
                            if (!hold_valid)
                                underflow <= 1;

                            shift_reg <= hold_data[6:0];
                            shift_reg_last <= hold_last;
                            hold_valid <= 0;

                            esdi_read_data_ungated <= hold_data[7];

                        end
                    end
                    else
                    begin
                        shift_reg <= {shift_reg[5:0], 1'b0};
                        esdi_read_data_ungated <= shift_reg[6];
                    end

                end
                else
                begin
                    esdi_read_data_ungated <= 0;
                end

            end


            if (!esdi_read_gate_shift[1] && esdi_read_gate_shift[0])
            begin
                // Look for instances where read gate was asserted when we were not reading
                if (!reading)
                    missed_deadline <= 1;
            end

            /* Register Interface*/

            if (csr_bready)
                csr_bvalid <= 0;

            if (csr_rready)
                csr_rvalid <= 0;

            if (csr_awvalid && csr_awready)
            begin
                write_addr_valid <= 1;
                write_addr <= csr_awaddr;
            end

            if (csr_wvalid && csr_wready)
            begin
                write_data_valid <= 1;
                write_data <= csr_wdata;
            end

            if (write_addr_valid && write_data_valid && (!csr_bvalid || csr_bready))
            begin
                write_addr_valid <= 0;
                write_data_valid <= 0;

                case (write_addr[4:2])
                    0 : control_register <= write_data;
                    1 : begin
                            missed_deadline <= write_data[1];
                            underflow <= write_data[0];
                        end
                    2 : clocks_per_halfbit <= write_data[6:0];
                endcase

                csr_bvalid <= 1;
                csr_bresp <= 2'b00;
            end

            if (csr_arvalid && (!csr_rvalid || csr_rready))
            begin

                case (csr_araddr[4:2])
                    0 : csr_rdata <= control_register;
                    1 : csr_rdata <= {30'b0, missed_deadline, underflow};
                    2 : csr_rdata <= {25'h0, clocks_per_halfbit};
                endcase

                csr_rvalid <= 1;
                csr_rresp <= 2'b00;
            end
        end
    end


endmodule