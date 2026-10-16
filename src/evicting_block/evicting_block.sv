module evicting_block #(
  parameter  int unsigned SET_NUM,
  parameter  int unsigned WAY_NUM,

  parameter  int unsigned LFSR_POLY  = 32'b1111_1111,
  parameter  int unsigned LFSR_WIDTH = $clog2(WAY_NUM),

  localparam int unsigned SET_WIDTH = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH = $clog2(WAY_NUM)
)(
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic [SET_WIDTH - 1:0] examine_set_i,
  input  logic [WAY_WIDTH - 1:0] hit_way_i,
  input  logic                   valid_i,
  input  logic                   hit_i,
  output logic [WAY_WIDTH - 1:0] victim_way_o
);

  wire valid_miss = valid_i && ~hit_i;

  logic [WAY_WIDTH - 1:0] mru_ff [SET_NUM];
  logic [  SET_NUM - 1:0] mru_en;
  wire  [WAY_WIDTH - 1:0] examine_mru;

  `ifdef FORMAL
  (* anyseq *) logic [WAY_WIDTH - 1:0] victim_way;
  `else
  logic [WAY_WIDTH - 1:0] victim_way;
  `endif

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < SET_NUM; i++) begin
        mru_ff[i] <= '0;
      end
    end else begin
      for (int i = 0; i < SET_NUM; i++) begin
        if (valid_i & mru_en[i]) begin
          mru_ff[i] <= hit_i ? hit_way_i : victim_way;
        end
      end
    end
  end

  assign mru_en = {{(SET_NUM - 1){1'b0}}, 1'b1} << examine_set_i;
  assign examine_mru = mru_ff[examine_set_i];
  assign victim_way_o = victim_way;

  `ifdef FORMAL
  always_comb begin : victim_assumption
    if (valid_miss) begin
      exclude_mru_way : assume (victim_way != examine_mru);
    end
  end
  `else
  prg #(
    .LFSR_WIDTH   ( LFSR_WIDTH  ),
    .LFSR_POLY    ( LFSR_POLY   )
  ) prg_inst (
    .clk          ( clk         ),
    .rst_n        ( rst_n       ),
    .exception_i  ( examine_mru ),
    .valid_i      ( valid_miss  ),
    .victim_way_o ( victim_way  )
  );
  `endif

  `ifdef FORMAL
  `include "evicting_block_sva.sv";
  `endif
endmodule : evicting_block