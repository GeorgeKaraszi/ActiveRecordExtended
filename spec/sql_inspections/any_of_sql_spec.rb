# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Any / None of SQL Queries" do
  let(:equal_query) { '"users"."personal_id" = 1' }
  let(:or_query)    { 'OR "users"."personal_id" = 2' }
  let(:equal_or)    { equal_query + " " + or_query }
  let(:join_query)  { /INNER JOIN \"tags\" ON \"tags\".\"user_id\" = \"users\".\"id/ }

  describe "where.any_of/1" do
    it "should group different column arguments into nested or conditions" do
      query = User.where.any_of({ personal_id: 1 }, { id: 2 }, { personal_id: 2 }).to_sql
      expect(query).to match_regex(/WHERE \(\(.+ = 1 OR .+ = 2\) OR .+ = 2\)/)
    end

    it "Should assign where clause predicates for standard queries" do
      query = User.where.any_of({ personal_id: 1 }, { personal_id: 2 }).to_sql
      expect(query).to include(equal_or)

      personal_one = User.where(personal_id: 1)
      personal_two = User.where(personal_id: 2)
      query = User.where.any_of(personal_one, personal_two).to_sql
      expect(query).to include(equal_or)
    end

    it "Joining queries should be added to the select statement" do
      user_two_tag = User.where(personal_id: 1).joins(:hm_tags)
      query = User.where.any_of(user_two_tag).to_sql
      expect(query).to match_regex(join_query)
      expect(query).to include(equal_query)
    end
  end

  describe "where.none_of/1" do
    it "Should surround the query in a WHERE NOT clause" do
      query = User.where.none_of({ personal_id: 1 }, { id: 2 }, { personal_id: 2 }).to_sql
      expect(query).to match_regex(/WHERE.+NOT \(\(.+ = 1 OR .+ = 2\) OR .+ = 2\)/)
    end
  end
end
