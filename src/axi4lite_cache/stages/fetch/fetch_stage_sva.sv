// =============================================================================
// Assumptions
// =============================================================================

logic f_past_valid = 1'b0;

always @(posedge clk) begin
  f_past_valid <= 1'b1;

  if (!f_past_valid) begin
    fs_initial_active_reset: assume (!rst_n);
  end else begin
    fs_no_reset: assume (rst_n);
  end
end

always @(posedge clk) begin : fs_axi_slave_valid_ready_assumes
  if (rst_n) begin
    fs_slave_ar_valid_ready_rule : assume (
      $fell(s_axi_arvalid_i) -> $past(s_axi_arready_o)
    );

    fs_slave_aw_valid_ready_rule : assume (
      !$fell(s_axi_awvalid_i) -> $past(s_axi_awready_o)
    );

    fs_slave_w_valid_ready_rule : assume (
      !$fell(s_axi_wvalid_i) -> $past(s_axi_wready_o)
    );
  end
end

// =============================================================================
// Support variables
// =============================================================================

logic arb_handshake;
assign arb_handshake = fm_valid_o & fm_ready_i;

logic buffer_write_valid;
assign buffer_write_valid = aw_valid & w_valid;

logic write_chosen;
assign write_chosen = fm_valid_o & fm_is_write_o;

logic read_chosen;
assign read_chosen = fm_valid_o & !fm_is_write_o;

logic external_mem_ready;
assign external_mem_ready = m_axi_awready_i & m_axi_wready_i;


// =============================================================================
// Assertions
// =============================================================================

// Check write address consistency between the arbiter and external memory.
always @(posedge clk) begin : fs_write_address_consistency
  if (rst_n && arb_handshake && fm_is_write_o) begin
    fs_write_address_matches_external : assert (fm_addr_o == m_axi_awaddr_o);
  end
end


// Check transaction selection and arbitration.
always @(posedge clk) begin : fs_transaction_arbitration
  if (rst_n && $past(rst_n)) begin
    case ({s_axi_arvalid_i, buffer_write_valid})
      2'b00: begin
        fs_no_transaction_no_valid : assert (!fm_valid_o);
      end
      2'b01: begin
        fs_write_selection_matches_memory_readiness : assert (
          write_chosen <-> external_mem_ready
        );
      end
      2'b10: begin
        fs_read_transaction_selected : assert (read_chosen);
      end
      2'b11: begin
        case (external_mem_ready)
          1'b0: begin
            fs_read_selected_when_memory_busy : assert (read_chosen);
          end
          1'b1: begin
            fs_transaction_valid_when_both_pending: assert (fm_valid_o);
            if ($past(arb_handshake)) begin
              // fs_arbiter_alternates_transaction_type : assert (
              //   // TODO: fm_is_write_o != $past(fm_is_write_o)
              // );
            end
          end
        endcase
      end
    endcase
  end
end

always @(posedge clk) begin
  if (rst_n) begin

    if ($past(s_axi_awvalid_i & s_axi_awready_o)) begin
      assert (!s_axi_awready_o -> $past(!arb_handshake) & !arb_handshake);
    end

  end
end