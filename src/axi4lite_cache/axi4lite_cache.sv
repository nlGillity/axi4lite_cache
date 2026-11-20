module axi4lite_cache #(
  parameter int unsigned ADDR_WIDTH = 32, // address width in bits
  parameter int unsigned DATA_WIDTH = 32, // fetched_data width in bits
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
  input  logic                    s_axi_arvalid_i, // read address fetched_valid from cpu
  output logic                    s_axi_arready_o, // read address ready to cpu
  // AW-channel
  input  logic [ADDR_WIDTH - 1:0] s_axi_awaddr_i,  // WriteData address from cpu
  input  logic                    s_axi_awvalid_i, // WriteData address fetched_valid from cpu
  output logic                    s_axi_awready_o, // WriteData address ready to cpu
  // W-channel
  input  logic [DATA_WIDTH - 1:0] s_axi_wdata_i,   // WriteData fetched_data from cpu
  input  logic [STRB_WIDTH - 1:0] s_axi_wstrb_i,   // WriteData byte strobes from cpu
  input  logic                    s_axi_wvalid_i,  // WriteData fetched_data fetched_valid from cpu
  output logic                    s_axi_wready_o,  // WriteData fetched_data ready to cpu
  // B-channel
  output logic [             1:0] s_axi_bresp_o,   // WriteData response to cpu
  output logic                    s_axi_bvalid_o,  // WriteData response fetched_valid to cpu
  input  logic                    s_axi_bready_i,  // WriteData response ready from cpu
  // R-channel
  output logic [             1:0] s_axi_rresp_o,   // read response to cpu
  output logic                    s_axi_rvalid_o,  // read fetched_data fetched_valid to cpu
  output logic [DATA_WIDTH - 1:0] s_axi_rdata_o,   // read fetched_data to cpu
  input  logic                    s_axi_rready_i,  // read fetched_data ready from cpu
  // ---------------------------------------------------------------------------
  // External memory AXI4-Lite interface (master)
  // ---------------------------------------------------------------------------
  // AR-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_araddr_o,  // read address to external memory
  output logic                    m_axi_arvalid_o, // read address fetched_valid to external memory
  input  logic                    m_axi_arready_i, // read address ready from external memory
  // AW-channel
  output logic [ADDR_WIDTH - 1:0] m_axi_awaddr_o,  // WriteData address to external memory
  output logic                    m_axi_awvalid_o, // WriteData address fetched_valid to external memory
  input  logic                    m_axi_awready_i, // WriteData address ready from external memory
  // W-channel
  output logic [DATA_WIDTH - 1:0] m_axi_wdata_o,   // WriteData fetched_data to external memory
  output logic [STRB_WIDTH - 1:0] m_axi_wstrb_o,   // WriteData byte strobes to external memory
  output logic                    m_axi_wvalid_o,  // WriteData fetched_data fetched_valid to external memory
  input  logic                    m_axi_wready_i,  // WriteData fetched_data ready from external memory
  // B-channel
  input  logic [             1:0] m_axi_bresp_i,  // WriteData response from external memory
  input  logic                    m_axi_bvalid_i, // WriteData response fetched_valid from external memory
  output logic                    m_axi_bready_o, // WriteData response ready to external memory
  // R-channel
  input  logic                    m_axi_rvalid_i, // read fetched_data fetched_valid from external memory
  input  logic [DATA_WIDTH - 1:0] m_axi_rdata_i,  // read fetched_data from external memory
  input  logic [             1:0] m_axi_rresp_i,  // read response from external memory
  output logic                    m_axi_rready_o  // read fetched_data ready to external memory
);

  // ===========================================================================
  // Cache-wide signals
  // ===========================================================================

  // Request valid
  logic fetched_valid;
  // Request ready
  logiv fetched_ready;
  // WriteData request flag
  logic fetched_xact;

  // Request address
  logic [ADDR_WIDTH - 1:0] fetched_addr;
  // Request tag (extracted from the fetched_addr)
  logic [TAG_WIDTH - 1:0] fetched_tag;
  assign fetched_tag = fetched_addr[ADDR_WIDTH - 1 -: TAG_WIDTH];
  // Request set (extracted from the fetched_addr)
  logic [SET_WIDTH - 1:0] fetched_set;
  assign fetched_set = fetched_addr[OFFSET_WIDTH +: SET_WIDTH];
  // Request fetched_data
  logic [DATA_WIDTH - 1:0] fetched_data;
  // Request strobes (per byte)
  logic [STRB_WIDTH - 1:0] fetched_strb_byte;

  // All tags from requested set
  logic [(WAY_NUM * (TAG_WIDTH + 1)) - 1:0] tag_ways;
  // All fetched_data from requested set
  logic [WAY_NUM * DATA_WIDTH - 1:0] data_ways;

  // Cache hit flag
  logic hit;
  // Hit way index
  logic [WAY_WIDTH - 1:0] hit_way;
  // Victim way index
  logic [WAY_WIDTH - 1:0] victim_way;
  // fetched_data extracted from the hit way
  logic [DATA_WIDTH - 1:0] hit_data;

  // AXI4-Lite signals
  // ---------------------------------------------------------------------------

  wire s_axi_bhandshake  = s_axi_bready_i  & s_axi_bvalid_o;
  wire s_axi_rhandshake  = s_axi_rready_i  & s_axi_rvalid_o;
  wire m_axi_arhandshake = m_axi_arvalid_o & m_axi_arready_i;
  wire m_axi_awhandshake = m_axi_awvalid_o & m_axi_awready_i;
  wire m_axi_whandshake  = m_axi_wvalid_o  & m_axi_wready_i;
  wire m_axi_bhandshake  = m_axi_bready_o  & m_axi_bvalid_i;
  wire m_axi_rhandshake  = m_axi_rready_o  & m_axi_rvalid_i;

  logic m_axi_rhandshake_ff;
  logic m_axi_bhandshake_ff;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      m_axi_rhandshake_ff <= 1'b0;
      m_axi_bhandshake_ff <= 1'b0;
    end else if (state == WAIT_RESPONSE) begin
      m_axi_rhandshake_ff <= m_axi_rhandshake;
      m_axi_bhandshake_ff <= m_axi_bhandshake;
    end else if (Complete) begin
      m_axi_rhandshake_ff <= 1'b0;
      m_axi_bhandshake_ff <= 1'b0;
    end
  end

  // ===========================================================================
  // FSM
  // ===========================================================================

  // Control signals
  logic Fetch;
  logic LookUp;
  logic RiseExtMemAR;
  logic RiseExtMemAW;
  logic RiseExtMemW;
  logic WriteData;
  logic WriteTag;
  logic Complete;

  // ---------------------------------------------------------------------------

  logic [ADDR_WIDTH - 1:0] current_addr_ff;
  logic [ TAG_WIDTH - 1:0] current_tag;
  logic [ SET_WIDTH - 1:0] current_set;

  logic [DATA_WIDTH - 1:0] current_data_ff;
  logic [DATA_WIDTH - 1:0] current_hit_data_ff;
  logic [STRB_WIDTH - 1:0] current_strb_byte_ff;
  logic [DATA_WIDTH - 1:0] current_strb_bit;
  logic                    current_xact_ff;

  logic                    current_hit_ff;
  logic [ WAY_WIDTH - 1:0] current_hit_way_ff;
  logic [DATA_WIDTH - 1:0] current_hit_data_ff;
  logic [ WAY_WIDTH - 1:0] current_victim_ff;

  assign current_tag = current_addr_ff[ADDR_WIDTH - 1 -: TAG_WIDTH];
  assign current_set = current_addr_ff[OFFSET_WIDTH +: SET_WIDTH];

  always_ff @(posedge clk) begin
    if (Fetch) begin
      current_addr_ff      <= fetched_addr;
      current_xact_ff      <= fetched_xact;
      current_data_ff      <= fetched_data;
      current_strb_byte_ff <= fetched_strb_byte;
    end
  end

  generate
    for (genvar i = 0; i < STRB_WIDTH; i++) begin : gen_bit_strb
      assign current_strb_bit[8 * i +: 8] = {8{current_strb_byte_ff[i]}};
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      current_hit_ff <= 1'b0;
    end
    if (LookUp) begin
      current_hit_ff      <= hit;
      current_hit_way_ff  <= hit_way;
      current_hit_data_ff <= hit_data;
      current_victim_ff   <= victim_way;
    end else if (Complete) begin
      current_hit_ff <= 1'b0;
    end
  end

  // FSM logic
  // ---------------------------------------------------------------------------

  typedef enum {
    IDLE,
    LOOKUP,
    WAIT_RESPONSE
  } state_e;

  state_e state, next_state;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    case (state)
      IDLE : if (fetched_valid & fetched_ready) begin
        next_state = LOOKUP;
      end

      LOOKUP : begin
        next_state = WAIT_RESPONSE;
      end

      WAIT_RESPONSE : begin
        case (current_xact_ff)
          1'b0 : if (m_axi_rhandshake_ff & s_axi_rhandshake) next_state = IDLE;
          1'b1 : if (m_axi_bhandshake_ff & s_axi_bhandshake) next_state = IDLE;
        endcase
      end

      default : next_state = state;
    endcase
  end

  always_comb begin
    Fetch        = 1'b0;
    LookUp       = 1'b0;
    RiseExtMemAR = 1'b0;
    RiseExtMemAW = 1'b0;
    RiseExtMemW  = 1'b0;
    WriteTag     = 1'b0;
    WriteData    = 1'b0;
    Complete     = 1'b0;

    case (state)
      IDLE : if (fetched_valid & fetched_ready) begin
        Fetch  = 1'b1;
        LookUp = 1'b1;
      end

      LOOKUP : begin
        WriteData    = current_hit_ff & current_xact_ff;
        RiseExtMemAR = ~current_hit_ff & ~current_xact_ff;
        RiseExtMemAW = current_xact_ff;
        RiseExtMemW  = current_xact_ff;
      end

      WAIT_RESPONSE : begin
        case (current_xact_ff)
          1'b0 : begin
            if ((current_hit_ff | m_axi_rhandshake_ff) & s_axi_rhandshake)
              Complete = 1'b1;
          end
          1'b1 : begin
            if ((current_hit_ff | m_axi_bhandshake_ff) & s_axi_bhandshake)
              Complete = 1'b1;
          end
        endcase

        WriteData = ~current_hit_ff & Complete;
        WriteTag  = ~current_hit_ff & Complete;
      end
    endcase
  end

  // ===========================================================================
  // Step 0: Fetch CPU transactions
  // ===========================================================================

  fetch_stage #(
    .ADDR_WIDTH      ( ADDR_WIDTH        ),
    .DATA_WIDTH      ( DATA_WIDTH        )
  ) fetch_stage_inst (
    .clk             ( clk               ),
    .rst_n           ( rst_n             ),

    .s_axi_araddr_i  ( s_axi_araddr_i    ),
    .s_axi_arvalid_i ( s_axi_arvalid_i   ),
    .s_axi_arready_o ( s_axi_arready_o   ),
    .s_axi_awaddr_i  ( s_axi_awaddr_i    ),
    .s_axi_awvalid_i ( s_axi_awvalid_i   ),
    .s_axi_awready_o ( s_axi_awready_o   ),
    .s_axi_wdata_i   ( s_axi_wdata_i     ),
    .s_axi_wstrb_i   ( s_axi_wstrb_i     ),
    .s_axi_wvalid_i  ( s_axi_wvalid_i    ),
    .s_axi_wready_o  ( s_axi_wready_o    ),

    .m_axi_awaddr_o  (                   ),
    .m_axi_awvalid_o (                   ),
    .m_axi_awready_i ( m_axi_awready_i   ),
    .m_axi_wdata_o   (                   ),
    .m_axi_wstrb_o   (                   ),
    .m_axi_wvalid_o  (                   ),
    .m_axi_wready_i  ( m_axi_wready_i    ),

    .fm_ready_i      ( fetched_ready     ),
    .fm_valid_o      ( fetched_valid     ),
    .fm_is_write_o   ( fetched_xact      ),
    .fm_addr_o       ( fetched_addr      ),
    .fm_data_o       ( fetched_data      ),
    .fm_strb_o       ( fetched_strb_byte )
  );

  // ===========================================================================
  // Step 1: Read from Memories
  // ===========================================================================

  tag_memory #(
    .TAG_WIDTH    ( TAG_WIDTH         ),
    .SET_NUM      ( SET_NUM           ),
    .WAY_NUM      ( WAY_NUM           )
  ) tag_memory_inst (
    .clk          ( clk               ),
    .rst_n        ( rst_n             ),

    .req_valid_i  ( fetched_valid     ),
    .req_ready_o  ( fetched_ready     ),
    .req_set_i    ( fetched_set       ),
    .credit_i     ( Complete          ),

    .write_en_i   ( WriteTag          ),
    .write_set_i  ( current_set       ),
    .write_way_i  ( current_victim_ff ),
    .write_tag_i  ( current_tag       ),
    .write_v_i    ( 1'b1              ),

    .tags_o       ( tag_ways          )
  );

  logic [ WAY_WIDTH - 1:0] wr_dmem_way;
  logic [DATA_WIDTH - 1:0] wr_dmem_data;
  logic [DATA_WIDTH - 1:0] wr_dmem_strb;

  always_comb begin
    if (current_hit_ff) begin
      wr_dmem_way  = current_hit_way_ff;
      wr_dmem_data = current_data_ff;
      wr_dmem_strb = current_strb_bit_ff;
    end else begin
      wr_dmem_way  = current_victim_ff;
      wr_dmem_data = m_axi_rdata_i;
      wr_dmem_strb = {DATA_WIDTH{1'b1}};
    end
  end

  data_memory #(
    .DATA_WIDTH   ( DATA_WIDTH    ),
    .SET_NUM      ( SET_NUM       ),
    .WAY_NUM      ( WAY_NUM       )
  ) data_memory_inst (
    .clk          ( clk           ),

    .read_en_i    ( fetched_valid ),
    .read_set_i   ( fetched_set   ),
    .data_o       ( data_ways     ),

    .write_en_i   ( WriteData     ),
    .write_set_i  ( current_set   ),
    .write_way_i  ( wr_dmem_way   ),
    .write_data_i ( wr_dmem_data  ),
    .write_strb_i ( wr_dmem_strb  )
  );

  // ===========================================================================
  // Stage 3: Analyse (check) request tag
  // ===========================================================================

  lookup_stage #(
    .ADDR_WIDTH     ( ADDR_WIDTH  ),
    .DATA_WIDTH     ( DATA_WIDTH   ),
    .SET_NUM        ( SET_NUM      ),
    .WAY_NUM        ( WAY_NUM      )
  ) lookup_stage_inst (
    .clk            ( clk          ),
    .rst_n          ( rst_n        ),

    .valid_i        ( LookUp       ),
    .examine_addr_i ( fetched_addr ),
    .tag_ways_i     ( tag_ways     ),
    .data_ways_i    ( data_ways    ),

    .hit_o          ( hit          ),
    .hit_way_o      ( hit_way      ),
    .hit_data_o     ( hit_data     ),
    .victim_way_o   ( victim_way   )
  );

  // ===========================================================================
  // External Memory AXI4-Lite transactions
  // ===========================================================================

  // Requests to External Memory
  // ---------------------------------------------------------------------------

  assign m_axi_araddr_o = current_addr_ff;

  always_ff @(posedge clk) begin : extmem_ar_req
    if (!rst_n) begin
      // No AR request after reset
      m_axi_arvalid_o <= 1'b0;
    end else if (RiseExtMemAR) begin
      // New AR request after miss occurance
      m_axi_arvalid_o <= 1'b1;
    end else if (m_axi_arhandshake) begin
      // Disassert AR request after handshake
      m_axi_arvalid_o <= 1'b0;
    end
  end

  assign m_axi_awaddr_o = current_addr_ff;

  always_ff @(posedge clk) begin : extmem_aw_req
    if (!rst_n) begin
      // No AW request after reset
      m_axi_awvalid_o <= 1'b0;
    end else if (RiseExtMemAW) begin
      // New AW request after miss occurance
      m_axi_awvalid_o <= 1'b1;
    end else if (m_axi_awhandshake) begin
      // Disassert AW request after handshake
      m_axi_awvalid_o <= 1'b0;
    end
  end

  assign m_axi_wdata_o = current_data_ff;
  assign m_axi_wstrb_o = current_strb_byte_ff;

  always_ff @(posedge clk) begin : extmem_w_req
    if (!rst_n) begin
      // No W request after reset
      m_axi_wvalid_o <= 1'b0;
    end else if (RiseExtMemW) begin
      // New W request after miss occurance
      m_axi_wvalid_o <= 1'b1;
    end else if (m_axi_whandshake) begin
      // Disassert W request after handshake
      m_axi_wvalid_o <= 1'b0;
    end
  end

  // Responses from External Memory
  // ---------------------------------------------------------------------------

  logic       m_axi_bvalid_ff;
  logic [1:0] m_axi_bresp_ff;

  always_ff @(posedge clk) begin : extmem_b_resp
    if (!rst_n) begin
      m_axi_bvalid_ff <= 1'b0;
      m_axi_bresp_ff  <= '0;
      m_axi_bready_o  <= 1'b1;
    end else if (~m_axi_bvalid_ff & m_axi_bhandshake) begin
      m_axi_bvalid_ff <= 1'b1;
      m_axi_bresp_ff  <= m_axi_bresp_i;
      m_axi_bready_o  <= 1'b0;
    end else if (s_axi_bhandshake) begin
      m_axi_bvalid_ff <= 1'b0;
      m_axi_bresp_ff  <= '0;
      m_axi_bready_o  <= 1'b1;
    end
  end

  logic                    m_axi_rvalid_ff;
  logic [DATA_WIDTH - 1:0] m_axi_rdata_ff;
  logic [             1:0] m_axi_rresp_ff;

  always_ff @(posedge clk) begin : extmem_r_resp
    if (!rst_n) begin
      m_axi_rvalid_ff <= 1'b0;
      m_axi_rdata_ff  <= '0;
      m_axi_rresp_ff  <= '0;
      m_axi_rready_o  <= 1'b1;
    end else if (~m_axi_rvalid_ff & m_axi_rhandshake) begin
      m_axi_rvalid_ff <= 1'b1;
      m_axi_rdata_ff  <= m_axi_rdata_i;
      m_axi_rresp_ff  <= m_axi_rresp_i;
      m_axi_rready_o  <= 1'b0;
    end else if (s_axi_rhandshake) begin
      m_axi_rvalid_ff <= 1'b0;
      m_axi_rdata_ff  <= '0;
      m_axi_rresp_ff  <= '0;
      m_axi_rready_o  <= 1'b1;
    end
  end

  // ===========================================================================
  // CPU AXI4-Lite transactions
  // ===========================================================================

  // Responses from Cache (bypass from External Memory)
  // ---------------------------------------------------------------------------

  always_comb begin
    s_axi_rvalid_o = '0;
    s_axi_rdata_o  = '0;
    s_axi_rresp_o  = '0;
    s_axi_bvalid_o = '0;
    s_axi_bresp_o  = '0;

    case ({current_hit_ff, current_xact_ff})
      2'b00 : begin
        s_axi_rvalid_o = m_axi_rvalid_ff;
        s_axi_rdata_o  = m_axi_rdata_ff;
        s_axi_rresp_o  = m_axi_rresp_ff;
      end
      2'b10 : begin
        s_axi_rvalid_o = 1'b1;
        s_axi_rdata_o  = current_hit_data_ff;
        s_axi_rresp_o  = `OKAY;
      end
      2'b01, 2'b11 : begin
        s_axi_bvalid_o = m_axi_bvalid_ff;
        s_axi_bresp_o  = m_axi_bresp_ff;
      end
    endcase
  end
endmodule : axi4lite_cache
