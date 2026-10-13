module reg_memory #(
  parameter int unsigned WORD_SIZE = 32,
  parameter int unsigned NUM_WORDS = 8,

  localparam int unsigned ADDR_WIDTH = $clog2(NUM_WORDS),
  localparam int unsigned STRB_WIDTH = WORD_SIZE / 8
)(
  input  logic                    clk,
  input  logic                    rst_n,
  
  input  logic                    sel,
  input  logic                    wr_en,
  input  logic [ADDR_WIDTH - 1:0] addr_i,
  input  logic [WORD_SIZE  - 1:0] data_i,
  input  logic [STRB_WIDTH - 1:0] strb_i,
  output logic [WORD_SIZE  - 1:0] data_o
);

  logic [WORD_SIZE - 1:0] mem [0:NUM_WORDS - 1];

  always_ff @(posedge clk) begin : mem_write_logic
    if (!rst_n) begin
      for (int i = 0; i < NUM_WORDS; i++) begin
        mem[i] <= '0;
      end
    end else if (wr_en & sel) begin
      for (int i = 0; i < WORD_SIZE / 8; i++) begin
        if (strb_i[i]) begin
          mem[addr_i][i*8 +: 8] <= data_i[i*8 +: 8];
        end
      end
    end
  end

  always_ff @(posedge clk) begin : mem_read_logic
    if (!rst_n) begin
      data_o <= '0;
    end else if (!wr_en & sel) begin
      data_o <= mem[addr_i];
    end
  end
endmodule : reg_memory