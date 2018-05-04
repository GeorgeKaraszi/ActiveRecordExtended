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

  describe "Any Array Element" do
    it "creates any predicates that contain a string value" do
      query = arel_table.where(arel_table[:tags].any("tag")).to_sql
      expect(query).to match_regex(/'tag' = ANY\("people"\."tags"\)/)
    end

    it "creates any predicates that contain a integer value" do
      query = arel_table.where(arel_table[:tags].any(2)).to_sql
      expect(query).to match_regex(/2 = ANY\("people"\."tags"\)/)
    end
  end

  describe "All Array Elements" do
    it "create all predicates that contain a string value" do
      query = arel_table.where(arel_table[:tags].all("tag")).to_sql
      expect(query).to match_regex(/'tag' = ALL\("people"\."tags"\)/)
    end

    it "create all predicates that contain a interger value" do
      query = arel_table.where(arel_table[:tags].all(2)).to_sql
      expect(query).to match_regex(/2 = ALL\("people"\."tags"\)/)
    end
  end

  describe "any_of([{column: value}, {column: value}]" do
    it "creates a combined set or predicate statements" do
      pp arel_table.any_of([{tows: 2, pool: 2}, {ppp: 55, zipper: 3}]).to_sql
    end
  end
end
