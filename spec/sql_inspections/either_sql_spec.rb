# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Either Methods SQL Queries" do
  let(:contains_array_regex) { /\"users\"\.\"tag_ids\" @> '\{1,2\}'/ }
  let(:profile_l_outer_join) { /LEFT OUTER JOIN \"profile_ls\" ON \"profile_ls\".\"user_id\" = \"users\".\"id\"/ }
  let(:profile_r_outer_join) { /LEFT OUTER JOIN \"profile_rs\" ON \"profile_rs\".\"user_id\" = \"users\".\"id\"/ }
  let(:where_join_case) do
    "WHERE ((CASE WHEN profile_ls.user_id IS NULL"\
    " THEN profile_rs.user_id"\
    " ELSE profile_ls.user_id END) "\
    "= users.id)"
  end

  let(:order_case) do
    "ORDER BY "\
    "(CASE WHEN profile_ls.likes IS NULL"\
    " THEN profile_rs.dislikes"\
    " ELSE profile_ls.likes END)"
  end

  describe ".either_join/2" do
    it "Should contain outer joins on the provided relationships" do
      query = User.either_join(:profile_l, :profile_r).to_sql
      expect(query).to match_regex(profile_l_outer_join)
      expect(query).to match_regex(profile_r_outer_join)
    end

    it "Should contain a case statement that will conditionally alternative between tables" do
      query = User.either_join(:profile_l, :profile_r).to_sql
      expect(query).to include(where_join_case)
    end
  end

  describe ".either_order/2" do
    let(:ascended_order)  { User.either_order(:asc, profile_l: :likes, profile_r: :dislikes).to_sql }
    let(:descended_order) { User.either_order(:desc, profile_l: :likes, profile_r: :dislikes).to_sql }

    it "Should contain outer joins on the provided relationships" do
      expect(ascended_order).to match_regex(profile_l_outer_join)
      expect(ascended_order).to match_regex(profile_r_outer_join)
      expect(descended_order).to match_regex(profile_l_outer_join)
      expect(descended_order).to match_regex(profile_r_outer_join)
    end

    it "Should contain a relational ordering case statement for a relations column" do
      expect(ascended_order).to include(order_case)
      expect(ascended_order).to end_with("asc")

      expect(descended_order).to include(order_case)
      expect(descended_order).to end_with("desc")
    end
  end
end
