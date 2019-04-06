# frozen_string_literal: true

require "spec_helper"

RSpec.describe Arel::Nodes::AggregateFunctionName do
  describe "Custom Aggregate function" do
    it "constructs an aggregate function based on a given name" do
      query = described_class.new("MY_CUSTOM_AGG", [Arel.sql("id == me")])
      expect(query.to_sql).to eq("MY_CUSTOM_AGG(id == me)")
    end

    it "can append multiple expressions" do
      query = described_class.new("MY_CUSTOM_AGG", [Arel.sql("id == me"), Arel.sql("id == you")])
      expect(query.to_sql).to eq("MY_CUSTOM_AGG(id == me, id == you)")
    end

    it "can append a distinct clause inside the aggregate" do
      query = described_class.new("MY_CUSTOM_AGG", [Arel.sql("id == me")], true)
      expect(query.to_sql).to eq("MY_CUSTOM_AGG(DISTINCT id == me)")
    end

    it "can append an order by clause when providing a ordering expression" do
      order_expr = Arel.sql("id").desc
      query      = described_class.new("MY_CUSTOM_AGG", [Arel.sql("id == me")], true).order_by([order_expr])
      expect(query.to_sql).to eq("MY_CUSTOM_AGG(DISTINCT id == me ORDER BY id DESC)")
    end

    it "can append multiple ordering clauses" do
      expr       = Arel.sql("id").desc
      other_expr = Arel.sql("name").asc
      query      = described_class.new("MY_CUSTOM_AGG", [Arel.sql("id == me")], true).order_by([expr, other_expr])
      expect(query.to_sql).to eq("MY_CUSTOM_AGG(DISTINCT id == me ORDER BY id DESC, name ASC)")
    end

    it "can be aliased" do
      alias_as = Arel.sql("new_name")
      query    = described_class.new("MY_CUSTOM_AGG", [Arel.sql("id == me")], true).as(alias_as)
      expect(query.to_sql).to eq("MY_CUSTOM_AGG(DISTINCT id == me) AS new_name")
    end
  end
end
