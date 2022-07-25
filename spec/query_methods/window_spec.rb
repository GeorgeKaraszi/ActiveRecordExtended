# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Window Function Query Methods" do
  let!(:user_one)   { User.create! }
  let!(:user_two)   { User.create! }

  let!(:tag_one)    { Tag.create!(user: user_one, tag_number: 1) }
  let!(:tag_two)    { Tag.create!(user: user_two, tag_number: 2) }

  let!(:tag_three)  { Tag.create!(user: user_one, tag_number: 3) }
  let!(:tag_four)   { Tag.create!(user: user_two, tag_number: 4) }

  let(:tag_group1)  { [tag_one, tag_three] }
  let(:tag_group2)  { [tag_two, tag_four] }

  describe ".window_select" do
    context "when using ROW_NUMBER() ordered in asc" do
      let(:base_query) do
        Tag.define_window(:w).partition_by(:user_id, order_by: :tag_number).select(:id)
      end

      it "returns tag_one with r_id 1 and tag_three with r_id 2" do
        results = base_query.select_window(:row_number, over: :w, as: :r_id).group_by(&:id)
        tag_group1.each.with_index { |tag, idx| expect(results[tag.id].first.r_id).to eq(idx + 1) }
      end

      it "returns tag_two with r_id 1 and tag_four with r_id 2" do
        results = base_query.select_window(:row_number, over: :w, as: :r_id).group_by(&:id)
        tag_group2.each.with_index { |tag, idx| expect(results[tag.id].first.r_id).to eq(idx + 1) }
      end
    end

    context "when using ROW_NUMBER() ordered in desc" do
      let(:base_query) do
        Tag.define_window(:w).partition_by(:user_id, order_by: { tag_number: :desc }).select(:id)
      end

      it "returns tag_one with r_id 2 and tag_three with r_id 1" do
        results = base_query.select_window(:row_number, over: :w, as: :r_id).group_by(&:id)
        tag_group1.reverse_each.with_index { |tag, idx| expect(results[tag.id].first.r_id).to eq(idx + 1) }
      end

      it "returns tag_two with r_id 2 and tag_four with r_id 1" do
        results = base_query.select_window(:row_number, over: :w, as: :r_id).group_by(&:id)
        tag_group2.reverse_each.with_index { |tag, idx| expect(results[tag.id].first.r_id).to eq(idx + 1) }
      end
    end

    context "when a window query is merged into another query" do
      let(:base_query) do
        Tag
          .define_window(:w).partition_by(:user_id, order_by: { tag_number: :desc })
          .select_window(:row_number, over: :w, as: :r_id)
          .select(:id)
      end

      it "maintains the window values" do
        other_query   = Tag.merge(base_query)
        base_results  = base_query.group_by(&:id)
        other_results = other_query.group_by(&:id)

        expect(base_query.to_sql).to eq(other_query.to_sql)
        expect(base_results).to match(other_results)
      end
    end
  end
end
