module axi4lite_cache #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned SET_NUM    = 4,
  parameter int unsigned WAY_NUM    = 4,
  parameter int unsigned DEBUG_ON   = 0,

  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8,
  localparam int unsigned SET_WIDTH  = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH  = $clog2(WAY_NUM)
)(
  input logic                     clk,
  input logic                     rst_n,
  // ---------------------------------------------------------------------------
  // CPU-side AXI4-Lite interface (slave)
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
  // B-channel
  output logic [             1:0] s_axi_bresp_o,
  output logic                    s_axi_bvalid_o,
  input  logic                    s_axi_bready_i,
  // R-channel
  output logic [             1:0] s_axi_rresp_o,
  output logic                    s_axi_rvalid_o,
  input  logic                    s_axi_rready_i,
  // ---------------------------------------------------------------------------
  // External memory AXI4-Lite interface (master)
  // ---------------------------------------------------------------------------
  // AR-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_araddr_o,
  output logic                    m_axi_arvalid_o,
  input  logic                    m_axi_arready_i,
  // AW-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_awaddr_o,
  output logic                    m_axi_awvalid_o,
  input  logic                    m_axi_awready_i,
  // W-channel
  output logic [DATA_WIDTH - 1:0] m_axi_wdata_o,
  output logic [STRB_WIDTH - 1:0] m_axi_wstrb_o,
  output logic                    m_axi_wvalid_o,
  input  logic                    m_axi_wready_i,
  // B-channel
  input  logic [             1:0] m_axi_bresp_i,
  input  logic                    m_axi_bvalid_i,
  output logic                    m_axi_bready_o,
  // R-channel
  input  logic [             1:0] m_axi_rresp_i,
  input  logic                    m_axi_rvalid_i,
  output logic                    m_axi_rready_o
);


endmodule : axi4lite_cache