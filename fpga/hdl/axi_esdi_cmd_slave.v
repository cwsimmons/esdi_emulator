
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

module axi_esdi_cmd_controller #(
    // Resonable settings assuming 100 MHz clock
    parameter DATA_SETUP = 6, // Command Data setup time. Minimum is 50ns
    parameter ACK_TO_NREQ = 6, // Transfer Ack to Transfer Req deassert. Minimum is 50ns
    parameter ATTN_TO_CMPL = 10,
    parameter BIT_TIMEOUT = 10_000_00 // 10ms
) (
    input csr_aclk,
    input csr_aresetn,

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

    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 intr INTERRUPT" *) 
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output interrupt,

    input esdi_transfer_req,
    input esdi_command_data,
    output esdi_transfer_ack,
    output esdi_confstat_data,

    output esdi_command_complete,
    output esdi_attention,
    output esdi_ready,
    output esdi_drive_selected
);

    reg write_addr_valid;
    reg write_data_valid;
    reg [4:0] write_addr;
    reg [31:0] write_data;

    assign csr_awready = !write_addr_valid;
    assign csr_wready = !write_data_valid;
    assign csr_arready = !csr_rvalid || csr_rready;

    reg [31:0] control_register;

    wire soft_reset = control_register[0];
    wire interface_enable = control_register[1];
    wire drive_selected = control_register[2];
    wire drive_ready = control_register[3];

    reg buffered_data_out_valid;
    reg [31:0] buffered_data_out;

    reg buffered_data_in_valid;
    reg [31:0] buffered_data_in;

    reg [2:0] state;
    reg sending;
    reg [5:0] bit_count;
    reg [31:0] cycle_count;
    reg [16:0] data_out;    // bit 0 is odd parity bit
    reg [16:0] data_in;

    reg transfer_ack;
    reg confstat_data;
    reg command_complete;
    reg command_pending;
    reg attention;

    reg [2:0] esdi_transfer_req_shift;
    reg [2:0] esdi_command_data_shift;


    assign esdi_transfer_ack = transfer_ack && drive_selected;
    assign esdi_confstat_data = confstat_data && drive_selected;
    assign esdi_command_complete = command_complete && interface_enable && drive_selected;
    assign esdi_attention = attention && drive_selected;
    assign esdi_ready = drive_ready && drive_selected;
    assign esdi_drive_selected = drive_selected;

    assign interrupt = command_pending;

    always @(posedge csr_aclk)
    begin
        if (!csr_aresetn)
        begin
           
            control_register <= 0;

            transfer_ack <= 0;
            confstat_data <= 0;

            command_complete <= 1;
            attention <= 0;
            
            state <= 0;
            bit_count <= 0;
            sending <= 0;


            buffered_data_out_valid <= 0;
            buffered_data_in_valid <= 0;

            write_addr_valid <= 0;
            write_data_valid <= 0;
            csr_bvalid <= 0;
            csr_rvalid <= 0;
        end
        else
        begin

            /* Serial Processing */

            cycle_count <= cycle_count + 1;

            esdi_transfer_req_shift <= {esdi_transfer_req, esdi_transfer_req_shift[2:1]};
            esdi_command_data_shift <= {esdi_command_data, esdi_command_data_shift[2:1]};
            

            // Wait for transfer req assert
            if (state == 0)
            begin
                if (esdi_transfer_req_shift[0] && interface_enable)
                begin
                    
                    if (!sending)
                    begin
                        data_in <= {data_in[15:0], esdi_command_data_shift[0]};
                    end
                    else
                    begin
                        confstat_data <= data_out[16];
                        data_out <= data_out << 1;
                    end

                    bit_count <= bit_count + 1;

                    state <= 1;
                    cycle_count <= 0;

                    if (bit_count == 0)
                    begin
                        command_complete <= 0;
                    end
                end
                else if ((bit_count | sending) && (cycle_count == BIT_TIMEOUT))
                begin
                    state <= 4;
                    cycle_count <= 0;
                end
            end
            // Wait a little bit before asserting transfer ACK
            else if (state == 1)
            begin
                if (cycle_count == DATA_SETUP)
                begin
                    transfer_ack <= 1;
                    cycle_count <= 0;
                    state <= 2;
                end
            end
            // Wait for transfer req deassert
            else if (state == 2)
            begin
                
                if (!esdi_transfer_req_shift[0])
                begin

                    cycle_count <= 0;
                    transfer_ack <= 0;

                    if (bit_count == 17)
                    begin

                        bit_count <= 0;

                        if (!sending)
                        begin
                            buffered_data_in_valid <= 1;
                            buffered_data_in <= {15'h0, (~^data_in[16:1] != data_in[0]), data_in[16:1]};
                            command_pending <= 1;
                            state <= 3;
                        end
                        else
                        begin
                            command_complete <= 1;
                            confstat_data <= 0;
                            state <= 0;
                            sending <= 0;
                        end

                    end
                    else
                    begin
                        state <= 0;
                    end

                end
                else if (cycle_count == BIT_TIMEOUT)
                begin
                    state <= 4;
                    cycle_count <= 0;
                end

            end
            // Wait for software to clear the command_pending bit
            else if (state == 3)
            begin
                if (!command_pending)
                begin

                    state <= 0;
                    cycle_count <= 0;

                    if (buffered_data_out_valid)
                    begin
                        sending <= 1;
                        buffered_data_out_valid <= 0;
                        data_out <= {buffered_data_out[15:0], ~^buffered_data_out[15:0]};
                    end
                    else
                    begin
                        sending <= 0;
                        command_complete <= 1;
                    end
                end
                else if (cycle_count == BIT_TIMEOUT)
                begin
                    state <= 4;
                    cycle_count <= 0;
                end
            end
            else if (state == 4)
            begin
                if (cycle_count == 0)
                begin
                    attention <= 1;
                end
                else if (cycle_count == ATTN_TO_CMPL)
                begin
                    state <= 0;
                    bit_count <= 0;
                    sending <= 0;
                    command_complete <= 1;
                    transfer_ack <= 0;
                end
            end

            if (soft_reset)
            begin
                attention <= 0;
                command_pending <= 0;
                buffered_data_out_valid <= 0;
                buffered_data_in_valid <= 0;
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
                    2 : begin
                        buffered_data_out_valid <= 1;
                        buffered_data_out <= write_data;
                    end
                    3 : if (write_data[0] == 0) command_pending <= 0;   // command_pending can only be cleared by software, not set
                    4 : attention <= write_data[0];
                endcase

                csr_bvalid <= 1;
                csr_bresp <= 2'b00;
            end

            if (csr_arvalid && (!csr_rvalid || csr_rready))
            begin

                case (csr_araddr[4:2])
                    0 : csr_rdata <= control_register;
                    1 : csr_rdata <= {28'h0, attention, command_pending, buffered_data_in_valid, buffered_data_out_valid};
                    2 : begin
                        csr_rdata <= buffered_data_in;
                        buffered_data_in_valid <= 0;
                    end
                    3 : csr_rdata <= {31'h0, command_pending};
                    4 : csr_rdata <= {31'h0, attention};
                endcase

                csr_rvalid <= 1;
                csr_rresp <= 2'b00;
            end

        end


    end


endmodule
