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
end
