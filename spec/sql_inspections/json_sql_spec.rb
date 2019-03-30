# frozen_string_literal: true

require "spec_helper"

RSpec.describe "JSON Methods SQL Queries" do
  let(:single_with)      { /^WITH .all_others. AS(?!.*WITH \w?)/mi }
  let(:override_with)    { /^WITH .all_others. AS \(.+WHERE .users.\..id. = 10\)/mi }

  describe ".select_row_to_json" do
    context "when a subquery contains a CTE table" do
      let(:cte_person) { User.with(all_others: User.where.not(id: 1)).where(id: 2) }

      it "should push the CTE to the callee's level" do
        query = User.select_row_to_json(cte_person, as: :results).to_sql
        expect(query).to match_regex(single_with)
      end

      it "should favor the parents CTE table if names collide" do
        query = User.with(all_others: User.where(id: 10))
        query = query.select_row_to_json(cte_person, as: :results).to_sql

        expect(query).to match_regex(single_with)
        expect(query).to match_regex(override_with)
      end
    end
  end

  describe ".json_build_object" do
    context "when a subquery contains a CTE table" do
      let(:cte_person) { User.with(all_others: User.where.not(id: 1)).where(id: 2) }

      it "should push the CTE to the callee's level" do
        query = User.json_build_object(:userss, cte_person).to_sql
        expect(query).to match_regex(single_with)
      end

      it "should favor the parents CTE table if names collide" do
        query = User.with(all_others: User.where(id: 10))
        query = query.json_build_object(:userss, cte_person).to_sql

        expect(query).to match_regex(single_with)
        expect(query).to match_regex(override_with)
      end
    end
  end
end
