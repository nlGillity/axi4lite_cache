logic f_past_valid = 1'b0;

wire f_write_eligible = aw_valid && w_valid && !ext_aw_full && !ext_w_full;
wire f_request_fire = fm_valid_o && fm_ready_i;
wire f_cpu_ar_fire = s_axi_arvalid_i && s_axi_arready_o;
wire f_ar_pop = ar_valid && ar_ready;

always @(posedge clk) begin : fs_reset_assumptions
  f_past_valid <= 1'b1;
  if (f_past_valid) begin
    fs_no_reset : assume (rst_n);
  end else begin
    fs_initial_active_reset : assume (!rst_n);
  end
end

always @(posedge clk) begin : fs_cpu_channel_assumptions
  if (f_past_valid && rst_n && $past(rst_n)) begin
    if ($past(s_axi_arvalid_i && !s_axi_arready_o)) begin
      fs_cpu_ar_stable : assume (s_axi_arvalid_i && $stable(s_axi_araddr_i));
    end
    if ($past(s_axi_awvalid_i && !s_axi_awready_o)) begin
      fs_cpu_aw_stable : assume (s_axi_awvalid_i && $stable(s_axi_awaddr_i));
    end
    if ($past(s_axi_wvalid_i && !s_axi_wready_o)) begin
      fs_cpu_w_stable : assume (s_axi_wvalid_i && $stable({s_axi_wstrb_i, s_axi_wdata_i}));
    end
  end
end

always @(posedge clk) begin : fs_arbitration_assertions
  if (rst_n) begin
    fs_write_eligibility : assert (arb_wr_valid == f_write_eligible);
    fs_request_valid : assert (fm_valid_o == (ar_valid || f_write_eligible));
    if (fm_valid_o) begin
      if (fm_is_write_o) begin
        fs_select_eligible_write : assert (f_write_eligible);
      end else begin
        fs_select_queued_read : assert (ar_valid && fm_addr_o == ar_addr);
      end
    end

    fs_write_handshake : assert (wr_fire == (f_request_fire && fm_is_write_o));
    fs_read_handshake : assert (f_ar_pop == (f_request_fire && !fm_is_write_o));
    fs_aw_pop : assert ((aw_valid && aw_ready) == wr_fire);
    fs_w_pop : assert ((w_valid && w_ready) == wr_fire);
  end
end

// The registered AR FIFO captures the CPU request before offering it to the arbiter.
always @(posedge clk) begin : fs_ar_fifo_assertions
  if (rst_n) begin
    fs_ar_ready : assert (s_axi_arready_o == !ar_valid);
    fs_ar_pointers : assert ({ar_buffer_inst.fifo.fifo_i.read_pointer_q,
                             ar_buffer_inst.fifo.fifo_i.write_pointer_q} == '0);

    if (f_past_valid) begin
      if (!$past(rst_n)) begin
        fs_ar_reset_empty : assert (!ar_valid);
      end else begin
        fs_ar_occupancy : assert (ar_valid == $past(f_cpu_ar_fire || (ar_valid && !f_ar_pop)));
        if ($past(f_cpu_ar_fire)) begin
          fs_ar_capture : assert (ar_addr == $past(s_axi_araddr_i));
        end else if ($past(ar_valid && !f_ar_pop)) begin
          fs_ar_stable : assert ($stable(ar_addr));
        end
      end
    end
  end
end

// The external FIFOs each hold one entry. An accepted write can bypass either
// independently. An entry that stalls occupies its slot until its handshake.
always @(posedge clk) begin : fs_external_fifo_assertions
  if (rst_n) begin
    // Both pointers of a depth-one FIFO always address its sole entry.
    fs_external_aw_pointers : assert ({ext_aw_fifo.read_pointer_q, ext_aw_fifo.write_pointer_q} == '0);
    fs_external_w_pointers : assert ({ext_w_fifo.read_pointer_q, ext_w_fifo.write_pointer_q} == '0);
    fs_external_aw_valid : assert (m_axi_awvalid_o == (ext_aw_full || wr_fire));
    fs_external_w_valid : assert (m_axi_wvalid_o == (ext_w_full || wr_fire));

    if (wr_fire) begin
      fs_external_aw_payload : assert (m_axi_awaddr_o == fm_addr_o);
      fs_external_w_payload : assert ({m_axi_wstrb_o, m_axi_wdata_o} == {fm_strb_o, fm_data_o});
    end

    if (f_past_valid && $past(rst_n)) begin
      fs_external_aw_occupancy : assert (ext_aw_full == $past(m_axi_awvalid_o && !m_axi_awready_i));
      fs_external_w_occupancy : assert (ext_w_full == $past(m_axi_wvalid_o && !m_axi_wready_i));

      if ($past(m_axi_awvalid_o && !m_axi_awready_i)) begin
        fs_external_aw_stable : assert (m_axi_awvalid_o && $stable(m_axi_awaddr_o));
      end
      if ($past(m_axi_wvalid_o && !m_axi_wready_i)) begin
        fs_external_w_stable : assert (m_axi_wvalid_o && $stable({m_axi_wstrb_o, m_axi_wdata_o}));
      end
    end
  end
end
