module comparator #(
  parameter int unsigned TAG_WIDTH,
  parameter int unsigned WAY_NUM
)(
  input  logic [                TAG_WIDTH - 1:0] examine_tag_i,
  input  logic [WAY_NUM * (TAG_WIDTH + 1) - 1:0] ways_i,

  output logic                                  hit_o,
  output logic [                 WAY_NUM - 1:0] hit_way_o
);

  localparam int unsigned VALID_POS  = TAG_WIDTH;
  localparam int unsigned TAG_LEFT   = TAG_WIDTH - 1;
  localparam int unsigned WORD_WIDTH = TAG_WIDTH + 1;

  wire [WAY_NUM - 1:0] comp_res;

  generate
    for (genvar i = 0; i < WAY_NUM; i++) begin : comparation_generator
      wire [TAG_WIDTH:0] way;
      assign way = ways_i[WORD_WIDTH*i +: WORD_WIDTH];

      assign comp_res[i] = way[VALID_POS] & (examine_tag_i == way[TAG_LEFT:0]);
    end
  endgenerate

  assign hit_o     = |comp_res;
  assign hit_way_o = comp_res;
endmodule : comparator