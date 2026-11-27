module prg #(
  parameter int unsigned           LFSR_WIDTH = 4,
  parameter bit [LFSR_WIDTH - 1:0] LFSR_POLY  = 4'b1010
)(
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic [LFSR_WIDTH - 1:0] exception_i,
  input  logic                    valid_i,
  output logic [LFSR_WIDTH - 1:0] victim_way_o
);

  logic [LFSR_WIDTH - 1:0] stage_ff;
  wire  [LFSR_WIDTH - 1:0] feedback;
  wire  [LFSR_WIDTH - 1:0] way_offset;
  wire  [LFSR_WIDTH - 1:0] stage_out;
  logic [LFSR_WIDTH - 1:0] poly;

  assign feedback = ~(stage_ff & exception_i);

  // A nonzero offset selects a different way modulo the index width.
  assign way_offset = (stage_ff == '0) ? LFSR_WIDTH'(1) : stage_ff;
  assign stage_out  = exception_i + way_offset;

  generate
    for (genvar i = 0; i < LFSR_WIDTH; i++) begin
      if (i < LFSR_WIDTH - 1) begin
        assign poly[i] = LFSR_POLY[i] 
                       ? (feedback[i] ^ poly[i + 1])
                       : poly[i + 1];
      end else begin
        assign poly[i] = feedback[i];
      end
    end
  endgenerate

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      stage_ff <= '0;
    end else if (valid_i) begin
      stage_ff[0] <= poly[0];
      for (int i = 1; i < LFSR_WIDTH; i++) begin
        stage_ff[i] <= feedback[i - 1];
      end
    end
  end

  assign victim_way_o = stage_out;
  
  `ifdef FORMAL
  `include "prg_sva.sv";
  `endif
endmodule : prg
