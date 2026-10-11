initial begin
  assume (rst_n == 1'b0);
end

always @(posedge clk) begin
  if (rst_n) begin
    if (valid_i)
      assert (victim_way_o != exception_i);
  end
end