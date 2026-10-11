module data_memory #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned SET_NUM    = 4,
  parameter int unsigned WAY_NUM    = 4,

  localparam int unsigned SET_WIDTH  = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH  = $clog2(WAY_NUM),
  localparam int unsigned STRB_WIDTH = DATA_WIDTH / 8
)(
  input  logic                              clk,

  input  logic                              is_write_i,
  input  logic [           SET_WIDTH - 1:0] set_i,
  input  logic [           WAY_WIDTH - 1:0] way_i, 
  input  logic [          DATA_WIDTH - 1:0] data_i,
  input  logic [          STRB_WIDTH - 1:0] strb_i,
  output logic [WAY_NUM * DATA_WIDTH - 1:0] data_o
);

  logic [WAY_NUM - 1:0] way_onehot;
  assign way_onehot = {{(WAY_NUM - 1){1'b0}}, 1'b1} << way_i;

  generate
    for (genvar i = 0; i < WAY_NUM; i++) begin : gen_mem_bank
      memory #(
        .WORD_SIZE ( DATA_WIDTH ),
        .NUM_WORDS ( SET_NUM    )
      ) mem_bank (
        .clk    ( clk                                  ),
        .sel    ( is_write_i ? way_onehot[i] : 1'b1    ),
        .wr_en  ( is_write_i                           ),
        .addr_i ( set_i                                ),
        .data_i ( data_i                               ),
        .strb_i ( strb_i                               ),
        .data_o ( data_o[i * DATA_WIDTH +: DATA_WIDTH] )
      );
    end
  endgenerate
endmodule : data_memory