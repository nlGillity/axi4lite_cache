module reg_memory #(
  parameter int unsigned WORD_SIZE = 32,
  parameter int unsigned NUM_WORDS = 8,

  localparam int unsigned ADDR_WIDTH = $clog2(NUM_WORDS)
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // Read port 0
  input  logic                    csb0,
  input  logic [ADDR_WIDTH - 1:0] addr0,
  output logic [WORD_SIZE - 1:0]  dout0,

  // Write port 1
  input  logic                    csb1,
  input  logic                    web1,
  input  logic [ADDR_WIDTH - 1:0] addr1,
  input  logic [WORD_SIZE - 1:0]  din1,
  input  logic [WORD_SIZE - 1:0]  strb1
);

  logic [WORD_SIZE - 1:0] mem [0:NUM_WORDS - 1];

  // Synchronous write
  always_ff @(posedge clk) begin : mem_write_logic
    if (!rst_n) begin
      for (int i = 0; i < NUM_WORDS; i++) begin
        mem[i] <= '0;
      end
    end else if (!csb1 && !web1) begin
      for (int i = 0; i < WORD_SIZE; i++) begin
        if (strb1[i]) begin
          mem[addr1][i] <= din1[i];
        end
      end
    end
  end

  // Combinational read
  always_comb begin : mem_read_logic
    if (!rst_n || csb0) begin
      dout0 = '0;
    end else begin
      dout0 = mem[addr0];
    end
  end

endmodule : reg_memory