# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Select Methods" do
  let(:numbers) { (1..10).to_a }

  describe ".foster_select" do
    context "with an aggregate function" do
      context "agg_array" do
        let(:number_set) { numbers.sample(6).to_enum }
        let!(:users) { Array.new(6) { User.create!(number: number_set.next, ip: "127.0.0.1") } }
        let!(:tags) { users.flat_map { |u| Array.new(2) { Tag.create!(user: u, tag_number: numbers.sample) } } }

        it "can accept a subquery" do
          subquery = Tag.select("count(*)").joins("JOIN users u ON tags.user_id = u.id").where("u.ip = users.ip")
          query    =
            User.foster_select(tag_count: [subquery, cast_with: :array_agg, distinct: true])
                .joins(:hm_tags)
                .group(:ip)
                .take

          expect(query.tag_count).to eq([tags.size])
        end

        it "can be ordered" do
          query = User.foster_select(
            asc_ordered_numbers:  [:number, cast_with: :array_agg, order_by: { number: :asc }],
            desc_ordered_numbers: [:number, cast_with: :array_agg, order_by: { number: :desc }],
          ).take

          expect(query.asc_ordered_numbers).to eq(number_set.to_a.sort)
          expect(query.desc_ordered_numbers).to eq(number_set.to_a.sort.reverse)
        end

        it "works with joined relations" do
          query =
            User.foster_select(tag_numbers: { tags: :tag_number, cast_with: :array_agg })
                .joins(:hm_tags)
                .take
          expect(query.tag_numbers).to match_array(Tag.pluck(:tag_number))
        end
      end

      context "bool_[and|or]" do
        let!(:users) do
          enum_numbers = numbers.to_enum
          Array.new(6) { User.create!(number: enum_numbers.next, ip: "127.0.0.1") }
        end

        it "will return a boolean expression" do
          query = User.foster_select(
            truthly_expr:     ["users.number > 0",   cast_with: :bool_and],
            falsey_expr:      ["users.number > 200", cast_with: :bool_and],
            other_true_expr:  ["users.number > 4",   cast_with: :bool_or],
            other_false_expr: ["users.number > 6",   cast_with: :bool_or],
          ).take

          expect(query.truthly_expr).to be_truthy
          expect(query.falsey_expr).to be_falsey
          expect(query.other_true_expr).to be_truthy
          expect(query.other_false_expr).to be_falsey
        end
      end

      context "with math functions: sum|max|min|avg" do
        before { 2.times.flat_map { |i| Array.new(2) { |j| User.create!(number: (i + 1) * j + 3) } } }

        it "max" do
          query = User.foster_select(max_num: [:number, cast_with: :max]).take
          expect(query.max_num).to eq(5)
        end

        it "min" do
          query = User.foster_select(max_num: [:number, cast_with: :min]).take
          expect(query.max_num).to eq(3)
        end

        it "sum" do
          query = User.foster_select(
            num_sum:      [:number, cast_with: :sum],
            distinct_sum: [:number, cast_with: :sum, distinct: true],
          ).take

          expect(query.num_sum).to eq(15)
          expect(query.distinct_sum).to eq(12)
        end

        it "avg" do
          query = User.foster_select(
            num_avg:      [:number, cast_with: :avg],
            distinct_avg: [:number, cast_with: :avg, distinct: true],
          ).take

          expect(query.num_avg).to eq(3.75)
          expect(query.distinct_avg).to eq(4.0)
        end
      end
    end

    context "with standard select items" do
      let!(:user) { User.create!(name: "Test") }

      it "works with no alias" do
        query = User.foster_select(:name).take
        expect(query.name).to eq(user.name)
      end

      it "works with alias" do
        query = User.foster_select(my_name: :name).take
        expect(query.my_name).to eq(user.name)
      end
    end
  end
end
