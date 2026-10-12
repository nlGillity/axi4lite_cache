module lookup_stage #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned SET_NUM    = 4,
  parameter int unsigned WAY_NUM    = 4,

  localparam int unsigned WAY_WIDTH    = $clog2(WAY_NUM),
  localparam int unsigned SET_WIDTH    = $clog2(SET_NUM),
  localparam int unsigned OFFSET_WIDTH = $clog2(DATA_WIDTH / 8),
  localparam int unsigned TAG_WIDTH    = ADDR_WIDTH - SET_WIDTH - OFFSET_WIDTH
)(
  input  logic                                     clk,
  input  logic                                     rst_n,

  input  logic                                     valid_i,
  input  logic [                 ADDR_WIDTH - 1:0] examine_addr_i,
  input  logic [(WAY_NUM * (TAG_WIDTH + 1)) - 1:0] tag_ways_i,
  input  logic [     (WAY_NUM * DATA_WIDTH) - 1:0] data_ways_i,

  output logic                                     hit_o,
  output logic [                  WAY_WIDTH - 1:0] hit_way_o,
  output logic [                 DATA_WIDTH - 1:0] hit_data_o,
  output logic [                  WAY_WIDTH - 1:0] victim_way_o
);

  logic [SET_WIDTH - 1:0] set_index;
  logic [TAG_WIDTH - 1:0] examine_tag;
  logic [  WAY_NUM - 1:0] hit_way_onehot;
  logic hit;
   
  assign set_index   = examine_addr_i[OFFSET_WIDTH + SET_WIDTH - 1:OFFSET_WIDTH];
  assign examine_tag = examine_addr_i[ADDR_WIDTH - 1:OFFSET_WIDTH + SET_WIDTH];

  comparator #(
    .TAG_WIDTH     ( TAG_WIDTH      ),
    .WAY_NUM       ( WAY_NUM        )
  ) comparator_inst (
    .examine_tag_i ( examine_tag    ),
    .ways_i        ( tag_ways_i     ),
    .hit_o         ( hit            ),
    .hit_way_o     ( hit_way_onehot )
  );

  cc_onehot_to_bin #(
    .OnehotWidth ( WAY_NUM        )
  ) ohehot_inst (
    .onehot_i    ( hit_way_onehot ),
    .bin_o       ( hit_way_o      )
  );

  evicting_block #(
    .SET_NUM       ( SET_NUM      ),
    .WAY_NUM       ( WAY_NUM      ),
    .LFSR_POLY     ( 1            ),
    .LFSR_WIDTH    ( WAY_WIDTH    )
  ) evicting_block_inst (
    .clk           ( clk          ),
    .rst_n         ( rst_n        ),
    .examine_set_i ( set_index    ),
    .hit_way_i     ( hit_way_o    ),
    .valid_i       ( valid_i      ),
    .hit_i         ( hit          ),
    .victim_way_o  ( victim_way_o )
  );

  assign hit_o = hit & valid_i;
  assign hit_data_o = data_ways_i[hit_way_o * DATA_WIDTH +: DATA_WIDTH];

  `ifdef DEBUG_ON
  int unsigned HIT_NUM;
  int unsigned MISS_NUM;
  int unsigned TOTAL_NUM;

  always_ff @(posedge clk) begin : statistics_block
    if (!rst_n) begin
      HIT_NUM   <= '0;
      MISS_NUM  <= '0;
      TOTAL_NUM <= '0;
    end else if (valid_i) begin
      TOTAL_NUM <= TOTAL_NUM + 1;
      HIT_NUM   <= HIT_NUM + hit_o;
      MISS_NUM  <= MISS_NUM + !hit_o;
    end
  end
`endif

endmodule : lookup_stage