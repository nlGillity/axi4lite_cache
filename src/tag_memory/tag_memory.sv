module tag_memory #(
  parameter int unsigned TAG_WIDTH  = 32,
  parameter int unsigned SET_NUM    = 4,
  parameter int unsigned WAY_NUM    = 4,

  localparam int unsigned SET_WIDTH  = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH  = $clog2(WAY_NUM),
  localparam int unsigned WORD_WIDTH = TAG_WIDTH + 1
)(
  input  logic                              clk,
  input  logic                              rst_n,

  input  logic                              credit_i,
  input  logic                              req_valid_i,
  output logic                              req_ready_o,
  input  logic [           SET_WIDTH - 1:0] req_set_i,

  input  logic                              write_en_i,
  input  logic [           SET_WIDTH - 1:0] write_set_i,
  input  logic [           WAY_WIDTH - 1:0] write_way_i,
  input  logic [           TAG_WIDTH - 1:0] write_tag_i,
  input  logic                              write_v_i,

  output logic [WAY_NUM * WORD_WIDTH - 1:0] tags_o
);

  wire fetch_handshake = req_valid_i & req_ready_o;

  // =========================================================================
  // Credit conuter
  // =========================================================================

  cc_credit_counter #(
    .NumCredits      ( 1               ),
    .InitCreditEmpty ( 1'b0            )
  ) credit_counter_inst (
    .clk_i           ( clk             ),
    .rst_ni          ( rst_n           ),
    .clr_i           ( 1'b0            ),
    .credit_o        (                 ),
    .credit_give_i   ( credit_i        ),
    .credit_take_i   ( fetch_handshake ),
    .credit_left_o   ( req_ready_o     ),
    .credit_crit_o   (                 ),
    .credit_full_o   (                 )
  );

  // =========================================================================
  // Tag Data
  // =========================================================================

  logic [WAY_NUM - 1:0] way_onehot;
  assign way_onehot = {{(WAY_NUM - 1){1'b0}}, 1'b1} << write_way_i;

  generate
    for (genvar i = 0; i < WAY_NUM; i++) begin : gen_mem_bank
      memory #(
        .WORD_SIZE ( TAG_WIDTH                            ),
        .NUM_WORDS ( SET_NUM                              )
      ) mem_bank (
        .clk       ( clk                                  ),
        .csb0      ( ~fetch_handshake                     ),
        .addr0     ( req_set_i                            ),
        .dout0     ( tags_o[i * WORD_WIDTH +: TAG_WIDTH]  ),
        .csb1      ( ~way_onehot[i]                       ),
        .web1      ( ~write_en_i                          ),
        .addr1     ( write_set_i                          ),
        .din1      ( write_tag_i                          ),
        .strb1     ( {TAG_WIDTH{1'b1}}                    )
      );
      assign tags_o[i * WORD_WIDTH + TAG_WIDTH] =
          (rst_n && fetch_handshake) ? valids[i][req_set_i] : 1'b0;
    end
  endgenerate

  // =========================================================================
  // Valid Bits
  // =========================================================================

  logic [SET_NUM - 1:0] valids [0:WAY_NUM - 1];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < WAY_NUM; i++) begin
        valids[i] <= '0;
      end
    end else if (write_en_i) begin
      valids[write_way_i][write_set_i] <= write_v_i;
    end
  end
endmodule : tag_memory
