# frozen_string_literal: true

require "spec_helper"

RSpec.describe "JSON Methods SQL Queries" do
  let(:single_with)      { /^WITH .all_others. AS(?!.*WITH \w?)/mi }
  let(:override_with)    { /^WITH .all_others. AS \(.+WHERE .users.\..id. = 10\)/mi }

  describe ".select_row_to_json" do
    context "when a subquery contains a CTE table" do
      let(:cte_person) { User.with(all_others: User.where.not(id: 1)).where(id: 2) }

      it "pushes the CTE to the callee's level" do
        query = User.select_row_to_json(cte_person, as: :results).to_sql
        expect(query).to match_regex(single_with)
      end

      it "favors the parents CTE table if names collide" do
        query = User.with(all_others: User.where(id: 10))
        query = query.select_row_to_json(cte_person, as: :results).to_sql

        expect(query).to match_regex(single_with)
        expect(query).to match_regex(override_with)
      end
    end

    context "when adding cast_with: option" do
      it "wraps the row_to_json expression with to_jsonb" do
        query = User.select_row_to_json(User.where(id: 10), cast_with: :to_jsonb, key: :convert_this, as: :results).to_sql
        expect(query).to match_regex(/SELECT \(SELECT TO_JSONB\(ROW_TO_JSON\("convert_this"\)\) FROM \(.+\).+\) AS "results"/)
      end

      it "casts object to an array" do
        query = User.select_row_to_json(User.where(id: 10), cast_with: :array, key: :convert_this, as: :results).to_sql
        expect(query).to match_regex(/SELECT \(ARRAY\(SELECT ROW_TO_JSON\("convert_this"\) FROM \(.+\).+\)\) AS "results"/)
      end

      it "casts object to an aggregated array" do
        query = User.select_row_to_json(User.where(id: 10), cast_with: :array_agg, key: :convert_this, as: :results).to_sql
        expect(query).to match_regex(/SELECT \(ARRAY_AGG\(\(SELECT TO_JSONB\(ROW_TO_JSON\("convert_this"\)\) FROM \(.+\).+\)\)\) AS "results"/)
      end

      it "casts query with to_jsonb and as an Array" do
        query = User.select_row_to_json(User.where(id: 10), cast_with: [:to_jsonb, :array], key: :convert_this, as: :results).to_sql
        expect(query).to match_regex(/SELECT \(ARRAY\(SELECT TO_JSONB\(ROW_TO_JSON\("convert_this"\)\) FROM \(.+\).+\)\) AS "results"/)
      end

      it "casts query as a distinct Aggregated Array" do
        query = User.select_row_to_json(User.where(id: 10), cast_with: [:array_agg, :distinct], key: :convert_this, as: :results).to_sql
        expect(query).to match_regex(/SELECT \(ARRAY_AGG\(DISTINCT \(SELECT TO_JSONB\(ROW_TO_JSON\("convert_this"\)\) FROM \(.+\).+\)\)\) AS "results"/)
      end
    end

    context "when the subquery is a STI record type" do
      it "does not append sti 'type IN(..)' where clauses to the nested query" do
        query = User.select_row_to_json(AdminSti.where(id: 10), cast_with: :array, key: :convert_this, as: :results).to_sql
        expect(query).to match_regex(/SELECT \(ARRAY\(SELECT ROW_TO_JSON\("convert_this"\) FROM \(.*\) convert_this\)\) AS .+/)
      end
    end
  end

  describe ".json_build_object" do
    context "when a subquery contains a CTE table" do
      let(:cte_person) { User.with(all_others: User.where.not(id: 1)).where(id: 2) }

      it "pushes the CTE to the callee's level" do
        query = User.json_build_object(:userss, cte_person).to_sql
        expect(query).to match_regex(single_with)
      end

      it "favors the parents CTE table if names collide" do
        query = User.with(all_others: User.where(id: 10))
        query = query.json_build_object(:users, cte_person).to_sql

        expect(query).to match_regex(single_with)
        expect(query).to match_regex(override_with)
      end
    end
  end
end
