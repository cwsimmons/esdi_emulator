
`timescale 1ns / 1ps


module axi_esdi_cmd_controller_tb ();

    reg csr_aclk;
    reg csr_aresetn;
    reg csr_awvalid;
    reg [4:0] csr_awaddr;
    reg csr_wvalid;
    reg [31:0] csr_wdata;
    reg csr_arvalid;
    reg [4:0] csr_araddr;

    reg esdi_transfer_req;
    reg esdi_command_data;

    axi_esdi_cmd_controller #(6, 6, 10, 40) uut0 (
        .csr_aclk               (csr_aclk),
        .csr_aresetn            (csr_aresetn),
        .csr_awvalid            (csr_awvalid),
        .csr_awready            (),
        .csr_awaddr             (csr_awaddr),
        .csr_awprot             (3'b000),
        .csr_wvalid             (csr_wvalid),
        .csr_wready             (),
        .csr_wdata              (csr_wdata),
        .csr_wstrb              (4'b1111),
        .csr_bvalid             (),
        .csr_bready             (1'b1),
        .csr_bresp              (),
        .csr_arvalid            (csr_arvalid),
        .csr_arready            (),
        .csr_araddr             (csr_araddr),
        .csr_arprot             (3'b000),
        .csr_rvalid             (),
        .csr_rready             (1'b1),
        .csr_rdata              (),
        .csr_rresp              (),

        .interrupt              (),
        
        .esdi_transfer_req      (esdi_transfer_req),
        .esdi_command_data      (esdi_command_data),
        .esdi_transfer_ack      (),
        .esdi_confstat_data     (),
        .esdi_command_complete  (),
        .esdi_attention         (),
        .esdi_ready             (),
        .esdi_drive_selected    ()
    );

    always #5 csr_aclk <= !csr_aclk;

    initial
    begin
        csr_aclk <= 0;
        csr_aresetn <= 0;
        csr_awvalid <= 0;
        csr_awaddr <= 0;
        csr_wvalid <= 0;
        csr_wdata <= 0;
        csr_arvalid <= 0;
        csr_araddr <= 0;

        esdi_transfer_req <= 0;
        esdi_command_data <= 0;

        #10;

        csr_aresetn <= 1;

        #10;

        csr_awvalid <= 1;
        csr_awaddr <= 0;
        csr_wvalid <= 1;
        csr_wdata <= 32'h0000000e;

        #10;

        csr_awvalid <= 0;
        csr_awaddr <= 0;
        csr_wvalid <= 0;
        csr_wdata <= 32'h00000000;

        #20;

        esdi_transfer_req <= 1;

    end

endmodule