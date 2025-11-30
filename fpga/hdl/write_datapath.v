
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

module write_datapath (
    input aclk,
    input aresetn,

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

    input [7:0] sector_number,
    input [31:0] cycle_count,

    input esdi_write_gate,
    input esdi_write_clock,
    input esdi_write_data,

    input esdi_read_data_ungated,
    input read_data_valid,

    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 intr INTERRUPT" *) 
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output interrupt,

    output parallel_tvalid,
    input parallel_tready,
    output [7:0] parallel_tdata,
    output parallel_tlast,
    output reg [7:0] parallel_tid
);

    reg write_addr_valid;
    reg write_data_valid;
    reg [4:0] write_addr;
    reg [31:0] write_data;

    assign csr_awready = !write_addr_valid;
    assign csr_wready = !write_data_valid;
    assign csr_arready = !csr_rvalid || csr_rready;

    reg [3:0] esdi_write_gate_shift;
    reg [3:0] esdi_write_clock_shift;
    reg [3:0] esdi_write_data_shift;

    reg [31:0] control_register;

    wire enable;
    wire soft_reset;
    wire interrupt_enable;

    assign enable = control_register[0];
    assign soft_reset = control_register[1];
    assign interrupt_enable = control_register[2];


    reg [9:0] unformatted_sector_length;

    reg sector_complete;
    reg sector_dirty;
    reg send_out;
    reg sector_discard;

    reg fifo_in_valid;
    wire fifo_in_ready;
    reg [7:0] fifo_in_data;
    reg fifo_in_last;

    wire fifo_out_valid;

    reg write_clock_edge;
    reg new_bit_valid;
    reg new_bit;
    reg active;
    reg [7:0] current_sector;
    reg new_byte_valid;
    reg [7:0] data_in;
    reg [2:0] bit_count;
    reg [9:0] byte_count;

    reg overflow;
    reg new_sector;
    reg new_sector_dirty;
    reg sector_missed;
    reg [7:0] new_sector_number;

    assign interrupt = new_sector & interrupt_enable;


    fifo_registered #(1, 10, 8, 0) fifo_of_uncertainty (
        .clk            (aclk),
        .reset_n        (!(sector_discard | !aresetn | soft_reset)),

        .in_tvalid      (fifo_in_valid),
        .in_tready      (fifo_in_ready),
        .in_tdata       (fifo_in_data),
        .in_tkeep       (1'b1),
        .in_tlast       (fifo_in_last),
        .in_tid         (8'b0),

        .out_tvalid     (fifo_out_valid),
        .out_tready     (parallel_tready & send_out),
        .out_tdata      (parallel_tdata),
        .out_tlast      (parallel_tlast),

        .num_free       (),
        .num_used       ()
    );

    assign parallel_tvalid = fifo_out_valid & send_out;

    always @(posedge aclk)
    begin

        esdi_write_gate_shift <= {esdi_write_gate, esdi_write_gate_shift[3:1]};
        esdi_write_clock_shift <= {esdi_write_clock, esdi_write_clock_shift[3:1]};
        esdi_write_data_shift <= {esdi_write_data, esdi_write_data_shift[3:1]};

        write_clock_edge <= 0;
        new_bit_valid <= 0;
        new_byte_valid <= 0;
        sector_discard <= 0;

        if (!aresetn)
        begin

            control_register <= 0;

            write_addr_valid <= 0;
            write_data_valid <= 0;
            csr_bvalid <= 0;
            csr_rvalid <= 0;

            active <= 0;
            overflow <= 0;
            new_sector <= 0;
            new_sector_dirty <= 0;
            sector_missed <= 0;
            fifo_in_valid <= 0;
            send_out <= 0;
            sector_complete <= 0;

        end
        else
        begin

            if (!esdi_write_clock_shift[0] && esdi_write_clock_shift[1])        // Look for rising edge of write clock 
                write_clock_edge <= 1;

            if (!esdi_write_gate_shift[0])
            begin
                // If write gate is asserted
                if (write_clock_edge)
                begin
                    new_bit_valid <= 1;
                    new_bit <= esdi_write_data_shift[0];
                end
            end
            else if (read_data_valid)
            begin
                new_bit_valid <= 1;
                new_bit <= esdi_read_data_ungated;
            end

            if (fifo_in_ready)
                fifo_in_valid <= 0;

            // Take note that this assume the sector in the fifo will be finished
            // reading out before the current sector completes.
            // The same note applies to how parallel_tid is handled.
            if (parallel_tvalid && parallel_tready && parallel_tlast)
                send_out <= 0;

            if (enable)
            begin

                // This number is chosen so that we guarantee the first instance of 'new_bit_valid & active' will
                // coincide with the first bit read out by the read datapath. If we don't account for that we might
                // cause our data to precess on each write. Basically we want to make sure that the same bit that
                // was read out will still be the first bit when we write a sector.
                if (cycle_count == 2) 
                begin
                    active <= 1;
                    bit_count <= 0;
                    byte_count <= 0;
                    sector_dirty <= 0;

                    current_sector <= sector_number;
                end

                if (new_bit_valid && active)
                begin
                    bit_count <= bit_count + 1;
                    data_in <= {data_in[6:0], new_bit};

                    if (bit_count == 3'b111)
                    begin
                        byte_count <= byte_count + 1;
                        new_byte_valid <= 1;
                    end
                end

                if (new_byte_valid && active)
                begin

                    fifo_in_valid <= 1;
                    fifo_in_data <= data_in;

                    if (byte_count == unformatted_sector_length)
                    begin
                        fifo_in_last <= 1;
                        active <= 0;
                        sector_complete <= 1;
                    end
                    else
                    begin
                        fifo_in_last <= 0;
                    end

                    if (fifo_in_valid)
                        overflow <= 1;

                end

                if (!esdi_write_gate_shift[1] && active)
                    sector_dirty <= 1;

                if (sector_complete)
                begin
                    sector_complete <= 0;
                    new_sector <= 1;
                    if (new_sector)
                        sector_missed <= 1;
                    new_sector_dirty <= sector_dirty;
                    new_sector_number <= current_sector;
                    if (sector_dirty)
                    begin
                        send_out <= 1;
                        parallel_tid <= current_sector;
                    end
                    else
                    begin
                        fifo_in_valid <= 0;
                        sector_discard <= 1;
                    end
                end

            end

            if (soft_reset)
            begin
                control_register <= 0;
                active <= 0;
                fifo_in_valid <= 0;
                overflow <= 0;
                sector_complete <= 0;
                new_sector <= 0;
                new_sector_dirty <= 0;
                sector_missed <= 0;
                send_out <= 0;
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
                        sector_missed <= write_data[3];
                        new_sector <= write_data[1];
                        overflow <= write_data[0];
                    end
                    3 : unformatted_sector_length <= write_data[9:0];
                endcase

                csr_bvalid <= 1;
                csr_bresp <= 2'b00;
            end

            if (csr_arvalid && (!csr_rvalid || csr_rready))
            begin

                case (csr_araddr[4:2])
                    0 : csr_rdata <= control_register;
                    1 : csr_rdata <= {29'b0, sector_missed, new_sector_dirty, new_sector, overflow};
                    2 : csr_rdata <= {24'b0, new_sector_number};
                    3 : csr_rdata <= {22'b0, unformatted_sector_length};
                endcase

                csr_rvalid <= 1;
                csr_rresp <= 2'b00;
            end
        end
    end


endmodule