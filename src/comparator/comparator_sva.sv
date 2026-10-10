logic [WAY_NUM - 1:0] expected_hit_way;

// =============================================================================
// Assumes
// =============================================================================

always begin : comp_unique_valid_tags_assumption
  // No two valid ways can contain the same tag
  for (int i = 0; i < WAY_NUM; i++) begin
    for (int j = i + 1; j < WAY_NUM; j++) begin
      comp_no_same_valid_tags : assume ((
          !(ways_i[i*(TAG_WIDTH + 1) + TAG_WIDTH] &&
          ways_i[j*(TAG_WIDTH + 1) + TAG_WIDTH])
        ) && (
          ways_i[i*(TAG_WIDTH + 1) +: TAG_WIDTH] ==
          ways_i[j*(TAG_WIDTH + 1) +: TAG_WIDTH]
        ));
      end
    end
end

// =============================================================================
// Assertions
// =============================================================================

always begin : comp_hit_assertion
  expected_hit_way = '0;

  for (int i = 0; i < WAY_NUM; i++) begin
    if (
      ways_i[i*(TAG_WIDTH+1) + TAG_WIDTH] &&                  // V-bit asserted
      (ways_i[i*(TAG_WIDTH+1) +: TAG_WIDTH] == examine_tag_i) // way was found
    ) begin
      expected_hit_way[i] = 1'b1;
      end
  end

  comp_onehot_hit_way : assert ($onehot0(hit_way_o));
  comp_output_hit_way : assert (hit_way_o == expected_hit_way);
  comp_output_hit     : assert (hit_o == (|expected_hit_way));
end