
`timescale 1ns / 1ps


module write_datapath_tb ();

    reg dp_csr_awvalid;
    reg [4:0] dp_csr_awaddr;
    reg dp_csr_wvalid;
    reg [31:0] dp_csr_wdata;
    reg dp_csr_arvalid;
    reg [4:0] dp_csr_araddr;

    reg csr_aclk;
    reg csr_aresetn;
    reg csr_awvalid;
    reg [4:0] csr_awaddr;
    reg csr_wvalid;
    reg [31:0] csr_wdata;
    reg csr_arvalid;
    reg [4:0] csr_araddr;

    wire [7:0] sector_number;
    wire [31:0] cycle_count;

    reg esdi_write_gate;
    reg esdi_write_clock;
    reg esdi_write_data;

    wire esdi_read_data_ungated;
    wire read_data_valid;

    wire interrupt;

    wire parallel_tvalid;
    wire parallel_tready;
    wire [7:0] parallel_tdata;
    wire parallel_tlast;
    wire [7:0] parallel_tid;

    wire esdi_index;
    wire esdi_sector;


    write_datapath uut0 (
        .aclk                   (csr_aclk),
        .aresetn                (csr_aresetn),

        .csr_awvalid            (dp_csr_awvalid),
        .csr_awready            (),
        .csr_awaddr             (dp_csr_awaddr),
        .csr_awprot             (3'b000),
        .csr_wvalid             (dp_csr_wvalid),
        .csr_wready             (),
        .csr_wdata              (dp_csr_wdata),
        .csr_wstrb              (4'b1111),
        .csr_bvalid             (),
        .csr_bready             (1'b1),
        .csr_bresp              (),
        .csr_arvalid            (dp_csr_arvalid),
        .csr_arready            (),
        .csr_araddr             (dp_csr_araddr),
        .csr_arprot             (3'b000),
        .csr_rvalid             (),
        .csr_rready             (1'b1),
        .csr_rdata              (),
        .csr_rresp              (),

        .sector_number          (sector_number),
        .cycle_count            (cycle_count),

        .esdi_write_gate        (esdi_write_gate),
        .esdi_write_clock       (esdi_write_clock),
        .esdi_write_data        (esdi_write_data),

        .esdi_read_data_ungated (esdi_read_data_ungated),
        .read_data_valid        (read_data_valid),

        .interrupt              (interrupt),
        
        .parallel_tvalid        (parallel_tvalid),
        .parallel_tready        (parallel_tready),
        .parallel_tdata         (parallel_tdata),
        .parallel_tlast         (parallel_tlast),
        .parallel_tid           (parallel_tid)
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

    wire labled_tvalid;
    wire [7:0] labled_tdata;
    wire labeled_tlast;

    labeler #(8) lab0 (

        .aclk(csr_aclk),
        .aresetn(csr_aresetn),

        .in_tvalid(parallel_tvalid),
        .in_tready(parallel_tready),
        .in_tdata(parallel_tdata),
        .in_tlast(parallel_tlast),
        .in_tid(parallel_tid),

        .out_tvalid(labled_tvalid),
        .out_tready(1'b1),
        .out_tdata(labled_tdata),
        .out_tlast(labeled_tlast)
    );

    always #5 csr_aclk <= !csr_aclk;

    assign read_data_valid = (cycle_count % 5) == 0;
    assign esdi_read_data_ungated = 1'b1;

    initial
    begin

        csr_aclk <= 0;
        csr_aresetn <= 0;

        dp_csr_awvalid <= 0;
        dp_csr_awaddr <= 0;
        dp_csr_wvalid <= 0;
        dp_csr_wdata <= 0;
        dp_csr_arvalid <= 0;
        dp_csr_araddr <= 0;

        csr_awvalid <= 0;
        csr_awaddr <= 0;
        csr_wvalid <= 0;
        csr_wdata <= 0;
        csr_arvalid <= 0;
        csr_araddr <= 0;

        esdi_write_gate <= 1;
        esdi_write_clock <= 0;
        esdi_write_data <= 0;

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

        #10;

        dp_csr_awvalid <= 1;
        dp_csr_awaddr <= 12;
        dp_csr_wvalid <= 1;
        dp_csr_wdata <= 11;

        #10;

        dp_csr_awvalid <= 0;
        dp_csr_wvalid <= 0;

        #10;

        dp_csr_awvalid <= 1;
        dp_csr_awaddr <= 0;
        dp_csr_wvalid <= 1;
        dp_csr_wdata <= 1;

        #10;

        dp_csr_awvalid <= 0;
        dp_csr_wvalid <= 0;
        dp_csr_awaddr <= 0;
        dp_csr_wdata <= 0;

        #20300;

        esdi_write_gate <= 0;

        #50;

        esdi_write_clock <= 1;

        #50;
        
        esdi_write_data <= 0;
        esdi_write_clock <= 0;

        #50;

        esdi_write_clock <= 1;

        #50;
        
        esdi_write_data <= 1;
        esdi_write_clock <= 0;

        #50;

        esdi_write_clock <= 1;

        #50;
        
        esdi_write_data <= 0;
        esdi_write_clock <= 0;

        #50;

        esdi_write_clock <= 1;

        #50;
        
        esdi_write_data <= 1;
        esdi_write_clock <= 0;

        #50;

        esdi_write_clock <= 1;

        #50;
        
        esdi_write_data <= 0;
        esdi_write_clock <= 0;

        #50;

        esdi_write_gate <= 1;


    end

endmodule