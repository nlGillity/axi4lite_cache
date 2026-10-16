module axi4lite_cache #(
  parameter int unsigned ADDR_WIDTH = 32, // address width in bits
  parameter int unsigned DATA_WIDTH = 32, // data width in bits
  parameter int unsigned SET_NUM    = 2,  // number of cache sets
  parameter int unsigned WAY_NUM    = 4,  // number of cache ways
  parameter int unsigned DEBUG_ON   = 0,  // enable sim-only logic

  localparam int unsigned STRB_WIDTH   = DATA_WIDTH / 8,
  localparam int unsigned SET_WIDTH    = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH    = $clog2(WAY_NUM),
  localparam int unsigned OFFSET_WIDTH = $clog2(DATA_WIDTH / 8),
  localparam int unsigned TAG_WIDTH    = ADDR_WIDTH - SET_WIDTH - OFFSET_WIDTH
)(
  input logic                     clk,             // clock
  input logic                     rst_n,           // sync active-low reset
  // ---------------------------------------------------------------------------
  // CPU-side AXI4-Lite interface (slave)
  // ---------------------------------------------------------------------------
  // AR-channel
  input  logic [ADDR_WIDTH - 1:0] s_axi_araddr_i,  // read address from cpu
  input  logic                    s_axi_arvalid_i, // read address req_valid from cpu
  output logic                    s_axi_arready_o, // read address ready to cpu
  // AW-channel
  input  logic [ADDR_WIDTH - 1:0] s_axi_awaddr_i,  // write address from cpu
  input  logic                    s_axi_awvalid_i, // write address req_valid from cpu
  output logic                    s_axi_awready_o, // write address ready to cpu
  // W-channel
  input  logic [DATA_WIDTH - 1:0] s_axi_wdata_i,   // write data from cpu
  input  logic [STRB_WIDTH - 1:0] s_axi_wstrb_i,   // write byte strobes from cpu
  input  logic                    s_axi_wvalid_i,  // write data req_valid from cpu
  output logic                    s_axi_wready_o,  // write data ready to cpu
  // B-channel
  output logic [             1:0] s_axi_bresp_o,   // write response to cpu
  output logic                    s_axi_bvalid_o,  // write response req_valid to cpu
  input  logic                    s_axi_bready_i,  // write response ready from cpu
  // R-channel
  output logic [             1:0] s_axi_rresp_o,   // read response to cpu
  output logic                    s_axi_rvalid_o,  // read data req_valid to cpu
  output logic [DATA_WIDTH - 1:0] s_axi_rdata_o,   // read data to cpu
  input  logic                    s_axi_rready_i,  // read data ready from cpu
  // ---------------------------------------------------------------------------
  // External memory AXI4-Lite interface (master)
  // ---------------------------------------------------------------------------
  // AR-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_araddr_o,  // read address to external memory
  output logic                    m_axi_arvalid_o, // read address req_valid to external memory
  input  logic                    m_axi_arready_i, // read address ready from external memory
  // AW-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_awaddr_o,  // write address to external memory
  output logic                    m_axi_awvalid_o, // write address req_valid to external memory
  input  logic                    m_axi_awready_i, // write address ready from external memory
  // W-channel
  output logic [DATA_WIDTH - 1:0] m_axi_wdata_o,   // write data to external memory
  output logic [STRB_WIDTH - 1:0] m_axi_wstrb_o,   // write byte strobes to external memory
  output logic                    m_axi_wvalid_o,  // write data req_valid to external memory
  input  logic                    m_axi_wready_i,  // write data ready from external memory
  // B-channel
  input  logic [             1:0] m_axi_bresp_i,  // write response from external memory
  input  logic                    m_axi_bvalid_i, // write response req_valid from external memory
  output logic                    m_axi_bready_o, // write response ready to external memory
  // R-channel
  input  logic                    m_axi_rvalid_i, // read data req_valid from external memory
  input  logic [DATA_WIDTH - 1:0] m_axi_rdata_i,  // read data from external memory
  input  logic [             1:0] m_axi_rresp_i,  // read response from external memory
  output logic                    m_axi_rready_o  // read data ready to external memory
);

  // ===========================================================================
  // Cache-wide signals
  // ===========================================================================

  logic credit;
  // All tags from requested set
  wire [(WAY_NUM * (TAG_WIDTH + 1)) - 1:0] tag_ways;
  // All data from requested set
  wire [WAY_NUM * DATA_WIDTH - 1:0] data_ways;

  // Current request signals
  // ---------------------------------------------------------------------------

  // Request valid
  wire req_valid;
  // Request ready
  wire req_ready;
  // Write request flag
  wire req_is_write;

  wire req_read = req_valid & ~req_is_write;
  wire req_write = req_valid & req_is_write;

  // Request address
  wire [ADDR_WIDTH - 1:0] req_addr;
  // Request tag (extracted from the req_addr)
  wire [TAG_WIDTH - 1:0] req_tag;
  assign req_tag = req_addr[ADDR_WIDTH - 1 -: TAG_WIDTH];
  // Request set (extracted from the req_addr)
  wire [SET_WIDTH - 1:0] req_set;
  assign req_set = req_addr[OFFSET_WIDTH +: SET_WIDTH];

  // Request data
  wire [DATA_WIDTH - 1:0] req_data;
  // Request strobes (per byte)
  wire [STRB_WIDTH - 1:0] req_strb_byte;
  // Request strobes (per bit)
  wire [DATA_WIDTH - 1:0] req_strb_bit;

  // Expand byte strobes to bit strobes
  generate
    for (genvar i = 0; i < STRB_WIDTH; i++) begin : gen_bit_strb
      assign req_strb_bit[8 * i +: 8] = {8{req_strb_byte[i]}};
    end
  endgenerate

  // Hit/Miss signals
  // ---------------------------------------------------------------------------

  // Cache hit flag
  wire hit;
  // Hit way index
  wire [WAY_WIDTH - 1:0] hit_way;
  // Victim way index
  wire [WAY_WIDTH - 1:0] victim_way;
  // Data extracted from the hit way
  wire [DATA_WIDTH - 1:0] hit_data;

  // Read hit: the requested data is found in the cache
  wire read_hit;
  assign read_hit = (hit & ~req_is_write) & req_valid;
  // Read miss: the requested data is not found in the cache
  wire read_miss;
  assign read_miss = (~hit & ~req_is_write) & req_valid;
  // Write hit: the write request matches a cached entry
  wire write_hit;
  assign write_hit = (hit & req_is_write) & req_valid;
  // Write miss: the write request does not match a cached entry
  wire write_miss;
  assign write_miss = (~hit & req_is_write) & req_valid;

  // AXI-Lite signals
  // ---------------------------------------------------------------------------

  wire s_axi_bhandshake = s_axi_bready_i & s_axi_bvalid_o;
  wire s_axi_rhandshake = s_axi_rready_i & s_axi_rvalid_o;

  wire m_axi_bhandshake = m_axi_bready_o & m_axi_bvalid_i;
  wire m_axi_rhandshake = m_axi_rready_o & m_axi_rvalid_i;

  // ===========================================================================
  // Stage 0: Fetch CPU transactions
  // ===========================================================================

  fetch_stage #(
    .ADDR_WIDTH      ( ADDR_WIDTH      ),
    .DATA_WIDTH      ( DATA_WIDTH      )
  ) fetch_stage_inst (
    .clk             ( clk             ),
    .rst_n           ( rst_n           ),

    .s_axi_araddr_i  ( s_axi_araddr_i  ),
    .s_axi_arvalid_i ( s_axi_arvalid_i ),
    .s_axi_arready_o ( s_axi_arready_o ),
    .s_axi_awaddr_i  ( s_axi_awaddr_i  ),
    .s_axi_awvalid_i ( s_axi_awvalid_i ),
    .s_axi_awready_o ( s_axi_awready_o ),
    .s_axi_wdata_i   ( s_axi_wdata_i   ),
    .s_axi_wstrb_i   ( s_axi_wstrb_i   ),
    .s_axi_wvalid_i  ( s_axi_wvalid_i  ),
    .s_axi_wready_o  ( s_axi_wready_o  ),

    .m_axi_awaddr_o  ( m_axi_awaddr_o  ),
    .m_axi_awvalid_o ( m_axi_awvalid_o ),
    .m_axi_awready_i ( m_axi_awready_i ),
    .m_axi_wdata_o   ( m_axi_wdata_o   ),
    .m_axi_wstrb_o   ( m_axi_wstrb_o   ),
    .m_axi_wvalid_o  ( m_axi_wvalid_o  ),
    .m_axi_wready_i  ( m_axi_wready_i  ),

    .fm_ready_i      ( req_ready       ),
    .fm_valid_o      ( req_valid       ),
    .fm_is_write_o   ( req_is_write    ),
    .fm_addr_o       ( req_addr        ),
    .fm_data_o       ( req_data        ),
    .fm_strb_o       ( req_strb_byte   )
  );

  // ===========================================================================
  // Stage 1: Memories
  // ===========================================================================

  always_comb begin : credit_logic
    case ({hit, req_is_write})
      2'b00 : credit = s_axi_rhandshake;
      2'b01 : credit = s_axi_bhandshake;
      2'b10 : credit = 1'b1;
      2'b11 : credit = s_axi_bhandshake;
    endcase
  end

  tag_memory #(
    .TAG_WIDTH    ( TAG_WIDTH  ),
    .SET_NUM      ( SET_NUM    ),
    .WAY_NUM      ( WAY_NUM    )
  ) tag_memory_inst (
    .clk          ( clk        ),
    .rst_n        ( rst_n      ),
    .req_valid_i  ( req_valid  ),
    .req_ready_o  ( req_ready  ),
    .req_set_i    ( req_set    ),
    .credit_i     ( credit     ),
    .write_en_i   ( read_miss  ),
    .write_set_i  ( req_set    ),
    .write_way_i  ( victim_way ),
    .write_tag_i  ( req_tag    ),
    .write_v_i    ( 1'b1       ),
    .tags_o       ( tag_ways   )
  );

  wire wr_dmem_en;
  assign wr_dmem_en = m_axi_rhandshake | write_hit;

  wire [WAY_WIDTH - 1:0] wr_dmem_way;
  assign wr_dmem_way = hit ? hit_way : victim_way;

  wire [DATA_WIDTH - 1:0] wr_dmem_data;
  assign wr_dmem_data = req_is_write ? req_data : m_axi_rdata_i;

  wire [DATA_WIDTH - 1:0] wr_dmem_strb;
  assign wr_dmem_strb = req_is_write ? req_strb_bit : {DATA_WIDTH{1'b1}};

  data_memory #(
    .DATA_WIDTH   ( DATA_WIDTH            ),
    .SET_NUM      ( SET_NUM               ),
    .WAY_NUM      ( WAY_NUM               )
  ) data_memory_inst (
    .clk          ( clk                   ),
    .read_en_i    ( req_valid & req_ready ),
    .read_set_i   ( req_set               ),
    .data_o       ( data_ways             ),
    .write_en_i   ( wr_dmem_en            ),
    .write_set_i  ( req_set               ),
    .write_way_i  ( wr_dmem_way           ),
    .write_data_i ( wr_dmem_data          ),
    .write_strb_i ( wr_dmem_strb          )
  );

  // ===========================================================================
  // Stage 3: Analyse (check) request tag
  // ===========================================================================

  lookup_stage #(
    .ADDR_WIDTH     ( ADDR_WIDTH ),
    .DATA_WIDTH     ( DATA_WIDTH ),
    .SET_NUM        ( SET_NUM    ),
    .WAY_NUM        ( WAY_NUM    )
  ) lookup_stage_inst (
    .clk            ( clk        ),
    .rst_n          ( rst_n      ),
    .valid_i        ( req_valid  ),
    .examine_addr_i ( req_addr   ),
    .tag_ways_i     ( tag_ways   ),
    .data_ways_i    ( data_ways  ),
    .hit_o          ( hit        ),
    .hit_way_o      ( hit_way    ),
    .hit_data_o     ( hit_data   ),
    .victim_way_o   ( victim_way )
  );

  // ===========================================================================
  // Stage 4: Miss logic
  // ===========================================================================

  // Read request after read miss
  // ---------------------------------------------------------------------------
  assign m_axi_araddr_o  = req_addr;
  assign m_axi_arvalid_o = read_miss;

  // Get data from External Memory
  // ---------------------------------------------------------------------------
  wire [1:0] external_resp;
  assign external_resp = m_axi_rresp_i;

  wire external_valid;
  assign external_valid = m_axi_rvalid_i;

  wire [DATA_WIDTH - 1:0] external_data;
  assign external_data = m_axi_rdata_i;

  // ===========================================================================
  // Stage 5: Responses
  // ===========================================================================

  // CPU R-channel
  // ---------------------------------------------------------------------------

  always_comb begin : cpu_r_channel_driving
    if (req_read) begin
      s_axi_rresp_o  = hit ? `OKAY    : external_resp; 
      s_axi_rvalid_o = hit ? 1'b1     : external_valid;
      s_axi_rdata_o  = hit ? hit_data : external_data; 
    end else begin
      s_axi_rresp_o  = '0;
      s_axi_rvalid_o = '0;
      s_axi_rdata_o  = '0;
    end
  end

  // CPU B-channel
  // ---------------------------------------------------------------------------
  assign s_axi_bresp_o  = m_axi_bresp_i;
  assign s_axi_bvalid_o = m_axi_bvalid_i;

  // External Memory R-channel
  // ---------------------------------------------------------------------------
  assign m_axi_rready_o = 1'b1;

  // External Memory B-channel
  // ---------------------------------------------------------------------------
  assign m_axi_bready_o = 1'b1;

// ===========================================================================
// Parameters checking
// ===========================================================================

initial begin : parameter_checks
  cache_data_width_a : assert (DATA_WIDTH == 32 || DATA_WIDTH == 64)
    else $error("DATA_WIDTH must be 32 or 64");

  cache_dimensions_a : assert (SET_NUM > 1 && WAY_NUM > 1)
    else $error("SET_NUM and WAY_NUM must be greater than 1");

  cache_address_configuration_a : assert (ADDR_WIDTH > SET_WIDTH + OFFSET_WIDTH)
    else $error("Invalid address and cache configuration");
end

endmodule : axi4lite_cache