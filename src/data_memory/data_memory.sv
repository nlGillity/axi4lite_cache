module data_memory #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned SET_NUM    = 4,
  parameter int unsigned WAY_NUM    = 4,

  localparam int unsigned SET_WIDTH  = $clog2(SET_NUM),
  localparam int unsigned WAY_WIDTH  = $clog2(WAY_NUM),
)(
  input  logic                              clk,

  input  logic                              read_en_i
  input  logic [           SET_WIDTH - 1:0] read_set_i,
  output logic [WAY_NUM * DATA_WIDTH - 1:0] data_o,

  input  logic                              write_en_i,
  input  logic [           SET_WIDTH - 1:0] write_set_i,
  input  logic [           WAY_WIDTH - 1:0] write_way_i,
  input  logic [          DATA_WIDTH - 1:0] write_data_i,
  input  logic [          DATA_WIDTH - 1:0] write_strb_i,
);

  logic [WAY_NUM - 1:0] way_onehot;
  assign way_onehot = {{(WAY_NUM - 1){1'b0}}, 1'b1} << write_way_i;

  generate
    for (genvar i = 0; i < WAY_NUM; i++) begin : gen_mem_bank
      memory #(
        .WORD_SIZE ( DATA_WIDTH                           ),
        .NUM_WORDS ( SET_NUM                              )
      ) mem_bank (
        .clk       ( clk                                  ),
        .csb0      ( ~read_en_i                           ),
        .addr0     ( read_set_i                           ),
        .dout0     ( data_o[i * DATA_WIDTH +: DATA_WIDTH] ),
        .csb1      ( ~way_onehot[i]                       ),
        .web1      ( ~write_en_i                          ),
        .addr1     ( write_set_i                          ),
        .din1      ( write_data_i                         ),
        .strb1     ( write_strb_i                         )
      );
    end
  endgenerate
endmodule : data_memory