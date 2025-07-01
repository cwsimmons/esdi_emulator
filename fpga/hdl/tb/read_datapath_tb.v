
`timescale 1ns / 1ps


module read_datapath_tb ();

    reg csr_aclk;
    reg csr_aresetn;
    reg csr_awvalid;
    reg [4:0] csr_awaddr;
    reg csr_wvalid;
    reg [31:0] csr_wdata;
    reg csr_arvalid;
    reg [4:0] csr_araddr;

    reg parallel_tvalid;
    wire parallel_tready;
    reg [7:0] parallel_tdata;
    reg parallel_tlast;
    reg [7:0] parallel_tid;

    wire esdi_read_data;
    wire esdi_read_clock;
    wire esdi_index;
    wire esdi_sector;

    wire [7:0] sector_number;
    wire [31:0] cycle_count;

    read_datapath uut0 (
        .csr_aclk               (csr_aclk),
        .csr_aresetn            (csr_aresetn),

        .parallel_aclk          (1'b0),
        .parallel_aresetn       (1'b0),

        .csr_awvalid            (1'b0),
        .csr_awready            (),
        .csr_awaddr             (5'b0),
        .csr_awprot             (3'b000),
        .csr_wvalid             (1'b0),
        .csr_wready             (),
        .csr_wdata              (32'b0),
        .csr_wstrb              (4'b1111),
        .csr_bvalid             (),
        .csr_bready             (1'b1),
        .csr_bresp              (),
        .csr_arvalid            (1'b0),
        .csr_arready            (),
        .csr_araddr             (5'b0),
        .csr_arprot             (3'b000),
        .csr_rvalid             (),
        .csr_rready             (1'b1),
        .csr_rdata              (),
        .csr_rresp              (),
        
        .parallel_tvalid        (parallel_tvalid),
        .parallel_tready        (parallel_tready),
        .parallel_tdata         (parallel_tdata),
        .parallel_tlast         (parallel_tlast),
        .parallel_tid           (parallel_tid),

        .sector_number          (sector_number),
        .cycle_count            (cycle_count),

        .esdi_read_gate         (),
        .esdi_read_data         (esdi_read_data),
        .esdi_read_clock        (esdi_read_clock)
    );

    sector_timer #(10) st0 (
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
        
        .esdi_index             (esdi_index),
        .esdi_sector            (esdi_sector),
        .sector_number          (sector_number),
        .cycle_count            (cycle_count)
    );

    always #5 csr_aclk <= !csr_aclk;

    always @(posedge csr_aclk)
    begin
        if (parallel_tvalid && parallel_tready)
        begin
            parallel_tdata <= parallel_tdata + 1;
            if (parallel_tdata % 8 == 6)
                parallel_tlast <= 1;
            else
                parallel_tlast <= 0;
            if (parallel_tdata % 8 == 7)
                parallel_tid <= parallel_tid + 1;
        end
    end

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

        parallel_tvalid <= 0;
        parallel_tdata <= 0;
        parallel_tlast <= 0;
        parallel_tid <= 0;

        #10;

        csr_aresetn <= 1;

        #10;

        csr_awvalid <= 1;
        csr_awaddr <= 4;
        csr_wvalid <= 1;
        csr_wdata <= 960; // 46296;   // 100 MHz / 60 rps / 36 spt

        #10;

        csr_awvalid <= 0;
        csr_wvalid <= 0;

        #10;

        csr_awvalid <= 1;
        csr_awaddr <= 8;
        csr_wvalid <= 1;
        csr_wdata <= 36;

        #10;

        csr_awvalid <= 0;
        csr_wvalid <= 0;

        #10;

        csr_awvalid <= 1;
        csr_awaddr <= 0;
        csr_wvalid <= 1;
        csr_wdata <= 1;

        #10;

        csr_awvalid <= 0;
        csr_awaddr <= 0;
        csr_wvalid <= 0;
        csr_wdata <= 32'h00000000;

        #20;

        parallel_tid <= 2;
        parallel_tvalid <= 1;

    end

endmodule