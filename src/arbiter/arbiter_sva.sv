// =============================================================================
// Assumes
// =============================================================================

initial begin : arb_init_assumes
  arb_initial_active_reset : assume (rst_n == 1'b0);
end

always @(posedge clk) begin : arb_valid_ready_assumes
  if (rst_n) begin
    // $fell(valid_a_i) -> $past(ready_a_o)
    arb_channel_a_valid_ready_rule : assume (!$fell(valid_a_i) || $past(ready_a_o));
    // $fell(valid_b_i) -> $past(ready_b_o)
    arb_channel_b_valid_ready_rule : assume (!$fell(valid_b_i) || $past(ready_b_o));
  end
end

// =============================================================================
// Assertions
// =============================================================================

always @(posedge clk) begin : arb_valid_ready_assertions
  if (rst_n) begin
    // $fell(valid_o) -> $past(ready_i)
    arb_output_valid_ready : assert (!$fell(valid_o) || $past(ready_i));
  end
end

always @(posedge clk) begin : arb_reset_assertions
  if ($rose(rst_n)) begin
    if (!valid_o) begin
      arb_init_grand : assert (channel_o == INIT_GRAND);
    end
  end
end

always @(posedge clk) begin : arb_channel_bypass_assertions
  if (rst_n) begin
    case ({valid_a_i, valid_b_i})
      2'b01 : begin
        arb_channal_b_bypass : assert (channel_o == 1'b1);
      end
      2'b10 : begin
        arb_channal_a_bypass : assert (channel_o == 1'b0);
      end
      2'b11 : begin
        if ($past(rst_n && ready_i && valid_o)) begin
          if (!(valid_a_i ^ valid_b_i)) begin
            arb_channel_toggling : assert (channel_o == ~$past(channel_o));
          end
        end
      end
    endcase
  end
end

always @(posedge clk) begin : arb_multiplexing_assertions
  if (rst_n) begin
    case (channel_o)
      1'b0 : begin
        // ready_a_o -> ready_i
        arb_channel_a_ready : assert (!ready_a_o || ready_i);
        arb_channel_a_data  : assert (data_o == data_a_i);
      end
      1'b1 : begin
        // ready_b_o -> ready_i
        arb_channel_b_ready : assert (!ready_b_o || ready_i);
        arb_channel_b_data  : assert (data_o == data_b_i);
      end
    endcase
  end
end

always @(posedge clk) begin : arb_total_assertions
  arb_single_channel_ready : assert (!(ready_a_o && ready_b_o));
end