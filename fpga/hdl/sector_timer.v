
module sector_timer #(
    parameter PULSE_WIDTH = 500 // should be about 5 us
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

    output reg esdi_index,
    output reg esdi_sector,
    output reg [31:0] cycle_count,
    output reg [7:0] sector_number,

    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 intr INTERRUPT" *) 
    (* X_INTERFACE_PARAMETER = "SENSITIVITY LEVEL_HIGH" *)
    output interrupt
);

    reg write_addr_valid;
    reg write_data_valid;
    reg [4:0] write_addr;
    reg [31:0] write_data;

    assign csr_awready = !write_addr_valid;
    assign csr_wready = !write_data_valid;
    assign csr_arready = !csr_rvalid || csr_rready;

    reg [31:0] control_register;

    wire enable = control_register[0];
    wire interrupt_enable = control_register[1];
    reg [31:0] sector_length;
    reg [31:0] interrupt_time;
    reg [7:0] num_sectors;

    reg interrupt_time_reached;
    assign interrupt = interrupt_time_reached && interrupt_enable;

    always @(posedge csr_aclk)
    begin
        if (!csr_aresetn)
        begin
            
            control_register <= 32'b0000;
            sector_length <= 0;
            num_sectors <= 0;

            cycle_count <= 0;
            sector_number <= 0;
            esdi_index <= 0;
            esdi_sector <= 0;

            write_addr_valid <= 0;
            write_data_valid <= 0;
            csr_bvalid <= 0;
            csr_rvalid <= 0;

            interrupt_time_reached <= 0;
        end
        else
        begin


            if (enable)
            begin
                cycle_count <= cycle_count + 1;

                if (cycle_count == 0)
                begin
                    if (sector_number == 0)
                        esdi_index <= 1;
                    else
                        esdi_sector <= 1;
                end
                else if (cycle_count == PULSE_WIDTH)
                begin
                    esdi_index <= 0;
                    esdi_sector <= 0;
                end
                else if (cycle_count == sector_length)
                begin
                    cycle_count <= 0;

                    if (sector_number == (num_sectors - 1))
                    begin
                        sector_number <= 0;
                    end
                    else
                    begin
                        sector_number <= sector_number + 1;
                    end

                end

                if (cycle_count == interrupt_time)
                begin
                    interrupt_time_reached <= 1;
                end

            end
            else
            begin

                cycle_count <= 0;
                sector_number <= 0;
                esdi_index <= 0;
                esdi_sector <= 0;

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
                    1 : sector_length <= write_data;           // Cannot be zero
                    2 : num_sectors <= write_data[7:0];
                    5 : interrupt_time <= write_data;
                endcase

                csr_bvalid <= 1;
                csr_bresp <= 2'b00;
            end

            if (csr_arvalid && (!csr_rvalid || csr_rready))
            begin

                case (csr_araddr[4:2])
                    0 : begin
                        csr_rdata <= {29'b0, interrupt_time_reached, control_register[1:0]};
                        interrupt_time_reached <= 0;
                    end
                    1 : csr_rdata <= sector_length;
                    2 : csr_rdata <= {24'b0, num_sectors};
                    3 : csr_rdata <= {24'b0, sector_number};
                    4 : csr_rdata <= cycle_count;
                    5 : csr_rdata <= interrupt_time;
                endcase

                csr_rvalid <= 1;
                csr_rresp <= 2'b00;
            end

        end
    end

endmodule