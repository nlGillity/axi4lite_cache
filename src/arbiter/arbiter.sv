module arbiter #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter bit          INIT_GRAND = 1'b0
)(
  input  logic                    clk,
  input  logic                    rst_n,

  input  logic                    ready_i,
  input  logic                    valid_a_i,
  input  logic                    valid_b_i,
  input  logic [DATA_WIDTH - 1:0] data_a_i,
  input  logic [DATA_WIDTH - 1:0] data_b_i,

  output logic                    channel_o,
  output logic                    ready_a_o,
  output logic                    ready_b_o,
  output logic                    valid_o,
  output logic [DATA_WIDTH - 1:0] data_o
);

  logic grand_ff;
    
  always_ff @(posedge clk) begin : grand_logic
    if (!rst_n) begin
      grand_ff <= INIT_GRAND;
    end else if (ready_i & valid_o) begin
      grand_ff <= !channel_o;
    end
  end

  assign valid_o   = valid_a_i | valid_b_i;
  assign channel_o = grand_ff ? (!valid_a_i | valid_b_i) : (!valid_a_i & valid_b_i);
  assign ready_a_o = ready_i && !channel_o;
  assign ready_b_o = ready_i &&channel_o;
  assign data_o    = channel_o ? data_b_i : data_a_i;
endmodule : arbiter