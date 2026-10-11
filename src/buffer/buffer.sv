module buffer #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned DEPTH      = 1
)(
  input  logic                    clk,
  input  logic                    rst_n,

  input  logic                    valid_i,
  output logic                    ready_o,
  input  logic [DATA_WIDTH - 1:0] data_i,

  output logic                    valid_o,
  input  logic                    ready_i,
  output logic [DATA_WIDTH - 1:0] data_o
);

  cc_stream_fifo #(
    .FallThrough ( 1'b1       ),
    .DataWidth   ( DATA_WIDTH ),
    .Depth       ( DEPTH      )
  ) fifo (
    .clk_i       ( clk        ), 
    .rst_ni      ( rst_n      ), 
    .clr_i       ( 1'b0       ),         
    .flush_i     ( 1'b0       ),        
    .usage_o     (            ),
    .data_i      ( data_i     ),
    .valid_i     ( valid_i    ),
    .ready_o     ( ready_o    ),
    .data_o      ( data_o     ),
    .valid_o     ( valid_o    ),
    .ready_i     ( ready_i    )
  );

endmodule : buffer