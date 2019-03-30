# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Inet Column Predicates" do
  let(:arel_table) { User.arel_table }

  describe "#inet_contained_within" do
    it "converts Arel inet contained within statement" do
      query = arel_table.where(arel_table[:ip].inet_contained_within(IPAddr.new("127.0.0.1"))).to_sql
      expect(query).to match_regex(%r{<< '127\.0\.0\.1/32'})
    end

    it "works with count" do
      expect(User.where(arel_table[:ip].inet_contained_within(IPAddr.new("127.0.0.1"))).count).to eq(0)
    end
  end

  describe "#inet_contained_within_or_equals" do
    it "converts Arel inet contained within statement" do
      query = arel_table.where(arel_table[:ip].inet_contained_within_or_equals(IPAddr.new("127.0.0.1"))).to_sql
      expect(query).to match_regex(%r{<<= '127\.0\.0\.1/32'})
    end

    it "works with count" do
      expect(User.where(arel_table[:ip].inet_contained_within_or_equals(IPAddr.new("127.0.0.1"))).count).to eq(0)
    end
  end

  describe "#inet_contains_or_equals" do
    it "converts Arel inet contained within statement" do
      query = arel_table.where(arel_table[:ip].inet_contains_or_equals(IPAddr.new("127.0.0.1"))).to_sql
      expect(query).to match_regex(%r{>>= '127\.0\.0\.1/32'})
    end

    it "works with count" do
      expect(User.where(arel_table[:ip].inet_contains_or_equals(IPAddr.new("127.0.0.1"))).count).to eq(0)
    end
  end

  describe "#inet_contains" do
    it "converts Arel inet contained within statement" do
      query = arel_table.where(arel_table[:ip].inet_contains("127.0.0.1")).to_sql
      expect(query).to match_regex(/>> '127\.0\.0\.1'/)
    end

    it "works with count" do
      expect(User.where(arel_table[:ip].inet_contains("127.0.0.1")).count).to eq(0)
    end
  end

  describe "#inet_contains_or_is_contained_within" do
    it "converts Arel inet contained within statement" do
      query = arel_table.where(arel_table[:ip].inet_contains_or_is_contained_within("127.0.0.1")).to_sql
      expect(query).to match_regex(/&& '127\.0\.0\.1'/)

      query = arel_table.where(arel_table[:ip].inet_contains_or_is_contained_within(IPAddr.new("127.0.0.1"))).to_sql
      expect(query).to match_regex(%r{&& '127\.0\.0\.1/32'})
    end

    it "works with count" do
      expect(User.where(arel_table[:ip].inet_contains_or_is_contained_within("127.0.0.1")).count).to eq(0)
      expect(User.where(arel_table[:ip].inet_contains_or_is_contained_within(IPAddr.new("127.0.0.1"))).count).to eq(0)
    end
  end
end
