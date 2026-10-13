module tag_memory #(
  parameter int unsigned TAG_WIDTH  = 32,
  parameter int unsigned SET_NUM    = 4,
  parameter int unsigned WAY_NUM    = 4,

  localparam int unsigned SET_WIDTH  = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH  = $clog2(WAY_NUM),
  localparam int unsigned WORD_WIDTH = TAG_WIDTH + 1
)(
  input  logic                              clk,
  input  logic                              rst_n

  input  logic                              credit_i,
  input  logic                              valid_i,
  output logic                              ready_o,

  input  logic                              is_write_i,
  input  logic [           SET_WIDTH - 1:0] read_set_i,
  input  logic [           SET_WIDTH - 1:0] write_set_i,
  input  logic [           WAY_WIDTH - 1:0] write_way_i, 
  input  logic [           TAG_WIDTH - 1:0] write_tag_i,

  output logic [WAY_NUM * WORD_WIDTH - 1:0] tags_o
);

  // ---------------------------------------------------------------------------
  // Credit conuter
  // ---------------------------------------------------------------------------

  cc_credit_counter #(
    .NumCredits      ( 1                 ),
    .InitCreditEmpty ( 1'b0              )
  ) credit_counter_inst (
    .clk_i           ( clk               ),
    .rst_ni          ( rst_n             ),
    .clr_i           ( 1'b0              ),
    .credit_o        (                   ),
    .credit_give_i   ( credit_i          ),
    .credit_take_i   ( valid_i & ready_o ),
    .credit_left_o   ( ready_o           ),
    .credit_crit_o   (                   ),
    .credit_full_o   (                   )
  );

  // ---------------------------------------------------------------------------
  // Memory
  // ---------------------------------------------------------------------------

  logic [WAY_NUM - 1:0] way_onehot;
  assign way_onehot = {{(WAY_NUM - 1){1'b0}}, 1'b1} << write_way_i;

  generate
    for (genvar i = 0; i < WAY_NUM; i++) begin : gen_mem_bank
      reg_memory #(
        .WORD_SIZE ( WORD_WIDTH ),
        .NUM_WORDS ( SET_NUM    )
      ) mem_bank (
        .clk    ( clk                                   ),
        .rst_n  ( rst_n                                 ),
        .sel    ( is_write_i ? way_onehot[i] : valid_i  ),
        .wr_en  ( is_write_i                            ),
        .addr_i ( is_write_i ? write_set_i : read_set_i ),
        .data_i ( {1'b1, write_tag_i}                   ),
        .strb_i ( {WORD_WIDTH{1'b1}}                    ),
        .data_o ( tags_o[i * WORD_WIDTH +: WORD_WIDTH]  )
      );
    end
  endgenerate
endmodule : data_memory