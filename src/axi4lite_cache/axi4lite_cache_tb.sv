`timescale 1ns/1ps

module axi4lite_cache_tb;
  
  // ===========================================================================
  // Parameters
  // ===========================================================================

  // DUT's parameters
  // ---------------------------------------------------------------------------

  localparam int unsigned ADDR_WIDTH = 32;
  localparam int unsigned DATA_WIDTH = 32;
  localparam int unsigned SET_NUM    = 32;
  localparam int unsigned WAY_NUM    = 4;

  // Support parameters
  // ---------------------------------------------------------------------------

  localparam int unsigned STRB_WIDTH   = DATA_WIDTH / 8;
  localparam int unsigned OFFSET_WIDTH = $clog2(DATA_WIDTH / 8);

  // ===========================================================================
  // Signals declaration
  // ===========================================================================

  // Clock and reset
  logic clk;
  logic rst_n;

  // CPU-side AXI4-Lite interface
  // ---------------------------------------------------------------------------

  logic [ADDR_WIDTH - 1:0] s_axi_araddr;
  logic                    s_axi_arvalid;
  logic                    s_axi_arready;

  logic [ADDR_WIDTH - 1:0] s_axi_awaddr;
  logic                    s_axi_awvalid;
  logic                    s_axi_awready;

  logic [DATA_WIDTH - 1:0] s_axi_wdata;
  logic [STRB_WIDTH - 1:0] s_axi_wstrb;
  logic                    s_axi_wvalid;
  logic                    s_axi_wready;

  logic [             1:0] s_axi_bresp;
  logic                    s_axi_bvalid;
  logic                    s_axi_bready;

  logic [             1:0] s_axi_rresp;
  logic                    s_axi_rvalid;
  logic [DATA_WIDTH - 1:0] s_axi_rdata;
  logic                    s_axi_rready;

  // External memory AXI4-Lite interface
  // ---------------------------------------------------------------------------

  logic [ADDR_WIDTH - 1:0] m_axi_araddr;
  logic                    m_axi_arvalid;
  logic                    m_axi_arready;

  logic                    m_axi_awvalid;
  logic [ADDR_WIDTH - 1:0] m_axi_awaddr;
  logic                    m_axi_awready;

  logic [DATA_WIDTH - 1:0] m_axi_wdata;
  logic [STRB_WIDTH - 1:0] m_axi_wstrb;
  logic                    m_axi_wvalid;
  logic                    m_axi_wready;

  logic [             1:0] m_axi_bresp;
  logic                    m_axi_bvalid;
  logic                    m_axi_bready;

  logic                    m_axi_rvalid;
  logic [DATA_WIDTH - 1:0] m_axi_rdata;
  logic [             1:0] m_axi_rresp;
  logic                    m_axi_rready;

  // ===========================================================================
  // DUT
  // ===========================================================================

  axi4lite_cache #(
    .ADDR_WIDTH      ( ADDR_WIDTH    ),
    .DATA_WIDTH      ( DATA_WIDTH    ),
    .SET_NUM         ( SET_NUM       ),
    .WAY_NUM         ( WAY_NUM       )
  ) DUT (
    .clk             ( clk           ),
    .rst_n           ( rst_n         ),

    .s_axi_araddr_i  ( s_axi_araddr  ),
    .s_axi_arvalid_i ( s_axi_arvalid ),
    .s_axi_arready_o ( s_axi_arready ),

    .s_axi_awaddr_i  ( s_axi_awaddr  ),
    .s_axi_awvalid_i ( s_axi_awvalid ),
    .s_axi_awready_o ( s_axi_awready ),

    .s_axi_wdata_i   ( s_axi_wdata   ),
    .s_axi_wstrb_i   ( s_axi_wstrb   ),
    .s_axi_wvalid_i  ( s_axi_wvalid  ),
    .s_axi_wready_o  ( s_axi_wready  ),

    .s_axi_bresp_o   ( s_axi_bresp   ),
    .s_axi_bvalid_o  ( s_axi_bvalid  ),
    .s_axi_bready_i  ( s_axi_bready  ),
    
    .s_axi_rresp_o   ( s_axi_rresp   ),
    .s_axi_rvalid_o  ( s_axi_rvalid  ),
    .s_axi_rdata_o   ( s_axi_rdata   ),
    .s_axi_rready_i  ( s_axi_rready  ),

    .m_axi_araddr_o  ( m_axi_araddr  ),
    .m_axi_arvalid_o ( m_axi_arvalid ),
    .m_axi_arready_i ( m_axi_arready ),

    .m_axi_awaddr_o  ( m_axi_awaddr  ),
    .m_axi_awvalid_o ( m_axi_awvalid ),
    .m_axi_awready_i ( m_axi_awready ),

    .m_axi_wdata_o   ( m_axi_wdata   ),
    .m_axi_wstrb_o   ( m_axi_wstrb   ),
    .m_axi_wvalid_o  ( m_axi_wvalid  ),
    .m_axi_wready_i  ( m_axi_wready  ),

    .m_axi_bresp_i   ( m_axi_bresp   ),
    .m_axi_bvalid_i  ( m_axi_bvalid  ),
    .m_axi_bready_o  ( m_axi_bready  ),

    .m_axi_rvalid_i  ( m_axi_rvalid  ),
    .m_axi_rdata_i   ( m_axi_rdata   ),
    .m_axi_rresp_i   ( m_axi_rresp   ),
    .m_axi_rready_o  ( m_axi_rready  )
  );

  // ===========================================================================
  // CPU PC memory
  // ===========================================================================

  localparam int unsigned CPU_PC_MEM_WORDS = 540;
  localparam string       CPU_PC_MEM_PATH  = "src/axi4lite_cache/pc_mem.hex";

  logic [ADDR_WIDTH - 1:0] cpu_pc_mem [0:CPU_PC_MEM_WORDS - 1];

  // Memory initialization
  // ---------------------------------------------------------------------------

  initial begin : cpu_pc_memory_init
    $readmemh(CPU_PC_MEM_PATH, cpu_pc_mem);
  end

  // ===========================================================================
  // External memory
  // ===========================================================================

  localparam int unsigned EXT_MEM_WORDS      = ADDR_WIDTH**2;
  localparam int unsigned EXT_MEM_ADDR_WIDTH = $clog2(EXT_MEM_WORDS);

  logic [DATA_WIDTH - 1:0] external_memory [0:EXT_MEM_WORDS - 1];

  // Memory initialization
  // ---------------------------------------------------------------------------

  initial begin : external_memory_init
    for (int i = 0; i < EXT_MEM_WORDS; i++) begin
      external_memory[i] = $urandom;
    end
  end

  // Memory model
  // ---------------------------------------------------------------------------

  assign m_axi_arready = 1'b1;
  assign m_axi_awready = 1'b1;
  assign m_axi_wready  = 1'b1;
  assign m_axi_rvalid  = m_axi_arvalid;
  assign m_axi_rresp   = `OKAY;
  assign m_axi_rdata   = external_memory[m_axi_araddr];
  assign m_axi_bvalid  = m_axi_awvalid & m_axi_wvalid;
  assign m_axi_bresp   = `OKAY;

  // Update external memory when both write channels handshake.
  always_ff @(posedge clk) begin : external_memory_write
    if (m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready) begin
      for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
        if (m_axi_wstrb[byte_idx]) begin
          external_memory[m_axi_awaddr][8*byte_idx +: 8] <= m_axi_wdata[8*byte_idx +: 8];
        end
      end
    end
  end

  // ===========================================================================
  // Tasks and Funcations
  // ===========================================================================

  // Wait clocks
  // ---------------------------------------------------------------------------

  task wait_clocks(int num);
    repeat (num) @(posedge clk);
  endtask : wait_clocks

  // CPU read transaction
  // ---------------------------------------------------------------------------

  task cpu_read (input logic [ADDR_WIDTH - 1:0] addr);
    // Drive the read request
    @(negedge clk);
    s_axi_araddr  = addr;
    s_axi_arvalid = 1'b1;

    fork
      begin : cpu_read_req_handshake_waiting
        // Wait for the address handshake
        @(negedge clk);
        wait(s_axi_arready);
        s_axi_arvalid = 1'b0;
        s_axi_araddr  = 'x;
      end

      begin : cp_read_resp_handshake_waiting
        // Wait for the read response if it has not arrived yet
        wait(s_axi_rvalid && s_axi_rready);
      end
    join
  endtask : cpu_read

  // CPU write transaction
  // ---------------------------------------------------------------------------

    // task automatic cpu_write(
    //     input logic [ADDR_WIDTH-1:0] addr,
    //     input logic [DATA_WIDTH-1:0] data,
    //     input logic [STRB_WIDTH-1:0] strb
    // );
    //     bit aw_done;
    //     bit w_done;
    //     bit resp_done;

    //     begin
    //         aw_done   = 1'b0;
    //         w_done    = 1'b0;
    //         resp_done = 1'b0;

    //         // Drive AW and W independently, with the same initial cycle.
    //         @(negedge clk);
    //         s_axi_awaddr_i  = addr;
    //         s_axi_awvalid_i = 1'b1;

    //         s_axi_wdata_i   = data;
    //         s_axi_wstrb_i   = strb;
    //         s_axi_wvalid_i  = 1'b1;

    //         // Wait for AW/W handshakes. Each VALID is held until accepted.
    //         while (!(aw_done && w_done)) begin
    //             @(posedge clk);

    //             if (!aw_done && s_axi_awready_o) begin
    //                 aw_done = 1'b1;
    //             end

    //             if (!w_done && s_axi_wready_o) begin
    //                 w_done = 1'b1;
    //             end

    //             if (s_axi_bvalid_o && s_axi_bready_i) begin
    //                 resp_done = 1'b1;
    //             end

    //             @(negedge clk);

    //             if (aw_done) begin
    //                 s_axi_awvalid_i = 1'b0;
    //             end

    //             if (w_done) begin
    //                 s_axi_wvalid_i = 1'b0;
    //             end
    //         end

    //         // Wait for the write response if it has not arrived yet.
    //         while (!resp_done) begin
    //             @(posedge clk);

    //             if (s_axi_bvalid_o && s_axi_bready_i) begin
    //                 resp_done = 1'b1;
    //             end
    //         end
    //     end
    // endtask

  // ===========================================================================
  // Preparations
  // ===========================================================================

  // Clock generation
  // ---------------------------------------------------------------------------

  initial begin : clock_generation
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Initial reset
  // ---------------------------------------------------------------------------

  initial begin : initial_reset
    // Default CPU-side inputs
    s_axi_araddr  = '0;
    s_axi_arvalid = 1'b0;
    s_axi_awaddr  = '0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata   = '0;
    s_axi_wstrb   = '0;
    s_axi_wvalid  = 1'b0;

    // CPU is always ready to accept responses
    s_axi_bready = 1'b1;
    s_axi_rready = 1'b1;

    // Reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
  end

  // Dumping
  // ---------------------------------------------------------------------------

  initial begin : dumping
    $dumpfile("build/axi4lite_cache_tb.vcd");
    $dumpvars(0, axi4lite_cache_tb);
  end

  // ===========================================================================
  // MAIN
  // ===========================================================================

  initial begin : main
    wait_clocks(10);

    // Transaction sequence
    for (int i = 0; i < CPU_PC_MEM_WORDS; i++) begin
      cpu_read(cpu_pc_mem[i]);
      repeat ($urandom_range(0, 5)) @(posedge clk);
    end

    wait_clocks(10);
    $finish;
  end
endmodule