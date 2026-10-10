// =============================================================================
// Assertions
// =============================================================================

always @(posedge clk) begin : evict_write_mru_assertions
  if (rst_n && !$initstate) begin
    if ($past(rst_n && valid_i)) begin
      // Most Recently Used update scenarios
      case ($past(hit_i))
        1'b0 : begin
          evict_miss_mru_rewrite : assert (
            mru_ff[$past(examine_set_i)] == $past(victim_way_o)
          );
        end
        1'b1 : begin
          evict_hit_mru_rewrite : assert (
            mru_ff[$past(examine_set_i)] == $past(hit_way_i)
          );
        end
      endcase

      // Most Recently Used rewrites only one register
      for (int i = 0; i < SET_NUM; i++) begin
        if (i != $past(examine_set_i)) begin
          evict_no_neighbour_rewrite : assert (
            mru_ff[i] == $past(mru_ff[i])
          );
        end
      end
    end
  end
end