module fetch_stage #(
  parameter  int unsigned ADDR_WIDTH = 32,
  parameter  int unsigned DATA_WIDTH = 32,
  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8
)(
  input logic                     clk,
  input logic                     rst_n,
  // ---------------------------------------------------------------------------
  // CPU-side AXI4-Lite signals (s, slave)
  // ---------------------------------------------------------------------------
  // AR-channel
  input  logic [ADDR_WIDTH - 1:0] s_axi_araddr_i,
  input  logic                    s_axi_arvalid_i,
  output logic                    s_axi_arready_o,
  // AW-channel
  input  logic [ADDR_WIDTH - 1:0] s_axi_awaddr_i,
  input  logic                    s_axi_awvalid_i,
  output logic                    s_axi_awready_o,
  // W-channel
  input  logic [DATA_WIDTH - 1:0] s_axi_wdata_i,
  input  logic [STRB_WIDTH - 1:0] s_axi_wstrb_i,
  input  logic                    s_axi_wvalid_i,
  output logic                    s_axi_wready_o,
  // ---------------------------------------------------------------------------
  // External memory AXI4-Lite interface (m, master)
  // ---------------------------------------------------------------------------
  // AW-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_awaddr_o,
  output logic                    m_axi_awvalid_o,
  input  logic                    m_axi_awready_i,
  // W-channel
  output logic [DATA_WIDTH - 1:0] m_axi_wdata_o,
  output logic [STRB_WIDTH - 1:0] m_axi_wstrb_o,
  output logic                    m_axi_wvalid_o,
  input  logic                    m_axi_wready_i,
  // ---------------------------------------------------------------------------
  // Fetch to Memory signals (fm) 
  // ---------------------------------------------------------------------------
  input  logic                    fm_ready_i,
  output logic                    fm_valid_o,
  output logic                    fm_is_write_o,
  output logic [ADDR_WIDTH - 1:0] fm_addr_o,
  output logic [DATA_WIDTH - 1:0] fm_data_o,
  output logic [STRB_WIDTH - 1:0] fm_strb_o
);

  // ===========================================================================
  // Signal declaration
  // ===========================================================================

  // CPU <-> Buffers
  // ---------------------------------------------------------------------------

  // Valid signal from AW buffer to Arbiter
  wire aw_valid;
  // Ready signal from Arbiter to AW buffer
  wire aw_ready;
  // Data from AW buffer to Arbiter
  wire [ADDR_WIDTH - 1:0] aw_data;

  // Valid signal from W buffer to Arbiter
  wire w_valid;
  // Ready signal from Arbiter to W buffer
  wire w_ready;
  // Data from W buffer to Arbiter
  wire [DATA_WIDTH - 1:0] w_data;
  // Strobes from W buffer to Arbiter
  wire [STRB_WIDTH - 1:0] w_strb;

  // Arbiter <-> Buffers
  // ---------------------------------------------------------------------------

  // Valid from Buffers to Arbiter's write channel
  wire arb_wr_valid;
  // Valid from Buffers to Arbiter's write channel
  wire arb_wr_ready;

  // FIFO's for extrnal memory
  // ---------------------------------------------------------------------------

  wire ext_aw_full;
  wire ext_aw_empty;

  wire ext_w_full;
  wire ext_w_empty;

  // ===========================================================================
  // Aribter-Buffers organization (to Memory)
  // ===========================================================================

  assign arb_wr_valid = (aw_valid & w_valid)          // buffers have valid data 
                      & (~ext_aw_full & ~ext_w_full); // external fifos ready

  assign w_ready  = aw_ready;
  assign aw_ready = arb_wr_ready                  // arbiter ready
                  & (~ext_aw_full & ~ext_w_full); // external fifos ready

  // Fetch AW buffer
  buffer #(
    .DATA_WIDTH ( ADDR_WIDTH      ),
    .DEPTH      ( 1               )
  ) aw_buffer_inst (
    .clk        ( clk             ),
    .rst_n      ( rst_n           ),

    .valid_i    ( s_axi_awvalid_i ),
    .ready_o    ( s_axi_awready_o ),
    .data_i     ( s_axi_awaddr_i  ),
    .valid_o    ( aw_valid        ),
    .ready_i    ( aw_ready        ),
    .data_o     ( aw_data         )
  );

  // Fetch W buffer
  buffer #(
    .DATA_WIDTH ( STRB_WIDTH + DATA_WIDTH        ),
    .DEPTH      ( 1                              )
  ) w_buffer_inst (
    .clk        ( clk                            ),
    .rst_n      ( rst_n                          ),

    .valid_i    ( s_axi_wvalid_i                 ),
    .ready_o    ( s_axi_wready_o                 ),
    .data_i     ( {s_axi_wstrb_i, s_axi_wdata_i} ),
    .valid_o    ( w_valid                        ),
    .ready_i    ( w_ready                        ),
    .data_o     ( {w_strb, w_data}               )
  );

  // Arbiter
  arbiter #(
    .DATA_WIDTH ( ADDR_WIDTH      ),
    .INIT_GRAND ( 1'b0            )
  ) arbiter_inst (
    .clk        ( clk             ),
    .rst_n      ( rst_n           ),

    .ready_i    ( fm_ready_i      ),
    .valid_a_i  ( s_axi_arvalid_i ),
    .valid_b_i  ( arb_wr_valid    ),
    .data_a_i   ( s_axi_araddr_i  ),
    .data_b_i   ( aw_data         ),

    .channel_o  ( fm_is_write_o   ),
    .ready_a_o  ( s_axi_arready_o ),
    .ready_b_o  ( arb_wr_ready    ),
    .valid_o    ( fm_valid_o      ),
    .data_o     ( fm_addr_o       )
  );

  assign fm_data_o = w_data;
  assign fm_strb_o = w_strb;

  // ===========================================================================
  // To extenral memory
  // ===========================================================================

  assign m_axi_awvalid_o = ~ext_aw_empty;
  assign m_axi_wvalid_o  = ~ext_w_empty;

  // FIFO for master's AW-channel
  cc_fifo #(
    .FallThrough ( 1'b1                                   ),
    .DataWidth   ( ADDR_WIDTH                             ),
    .Depth       ( 1                                      )
  ) ext_aw_fifo (
    .clk_i       ( clk                                    ),
    .rst_ni      ( rst_n                                  ),
    .clr_i       ( 1'b0                                   ),
    .flush_i     ( 1'b0                                   ),
    .full_o      ( ext_aw_full                            ),
    .empty_o     ( ext_aw_empty                           ),
    .usage_o     (                                        ),
    .data_i      ( aw_data                                ),
    .push_i      ( aw_valid & arb_wr_ready & ~ext_aw_full ),
    .data_o      ( m_axi_awaddr_o                         ),
    .pop_i       ( m_axi_awready_i & ~ext_aw_empty        )
  );

  // FIFO for master's W-channel
  cc_fifo #(
    .FallThrough ( 1'b1                                 ),
    .DataWidth   ( STRB_WIDTH + DATA_WIDTH              ),
    .Depth       ( 1                                    )
  ) ext_w_fifo (
    .clk_i       ( clk                                  ),
    .rst_ni      ( rst_n                                ),
    .clr_i       ( 1'b0                                 ),
    .flush_i     ( 1'b0                                 ),
    .full_o      ( ext_w_full                           ),
    .empty_o     ( ext_w_empty                          ),
    .usage_o     (                                      ),
    .data_i      ( {w_strb, w_data}                     ),
    .push_i      ( w_valid & arb_wr_ready & ~ext_w_full ),
    .data_o      ( {m_axi_wstrb_o, m_axi_wdata_o}       ),
    .pop_i       ( m_axi_wready_i & ~ext_w_empty        )
  );

  `ifdef FORMAL
  `include "fetch_stage_sva.sv";
  `endif
endmodule : fetch_stage