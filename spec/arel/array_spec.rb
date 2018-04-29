# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Array Column Predicates" do
  let(:arel_table) { Person.arel_table }

  describe "Array Overlap" do
    it "converts Arel overlap statement" do
      query = arel_table.where(arel_table[:tags].overlap(["tag", "tag 2"])).to_sql
      expect(query).to match_regex(/&& '\{"?tag"?,"tag 2"\}'/)
    end

    it "converts Arel overlap statement" do
      query = arel_table.where(arel_table[:tag_ids].overlap([1, 2])).to_sql
      expect(query).to match_regex(/&& '\{1,2\}'/)
    end

    it "works with count (and other predicates)" do
      expect(Person.where(arel_table[:tag_ids].overlap([1, 2])).count).to eq 0
    end
  end

  describe "Array Contains" do
    it "converts Arel contains statement and escapes strings" do
      query = arel_table.where(arel_table[:tags].contains(["tag", "tag 2"])).to_sql
      expect(query).to match_regex(/@> '\{"?tag"?,"tag 2"\}'/)
    end

    it "converts Arel contains statement with numbers" do
      query = arel_table.where(arel_table[:tag_ids].contains([1, 2])).to_sql
      expect(query).to match_regex(/@> '\{1,2\}'/)
    end

    it "works with count (and other predicates)" do
      expect(Person.where(arel_table[:tag_ids].contains([1, 2])).count).to eq 0
    end
  end
end
