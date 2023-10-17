# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record WINDOW Query inspection" do
  describe "#define_window" do
    context "when there is a single defined window" do
      it "contains a single defined window statement at the bottom" do
        query = Tag.define_window(:w_test).partition_by(:user_id).to_sql
        expect(query).to eq('SELECT "tags".* FROM "tags" WINDOW w_test AS (PARTITION BY user_id)')
      end

      it "returns a single defined window with a defined ORDER BY" do
        query = Tag.define_window(:w_test).partition_by(:user_id, order_by: { tags: { user_id: :desc } }).to_sql
        expect(query).to end_with("WINDOW w_test AS (PARTITION BY user_id ORDER BY tags.user_id DESC)")
      end

      it "places the window function below the WHERE and GROUP BY statements" do
        query = Tag.define_window(:w_test).partition_by(:user_id).where(id: 1).group(:user_id).to_sql
        expect(query).to eq('SELECT "tags".* FROM "tags" WHERE "tags"."id" = 1 GROUP BY "tags"."user_id" WINDOW w_test AS (PARTITION BY user_id)')
      end
    end

    context "when there are multiple defined windows" do
      it "contain a single defined window statement at the bottom" do
        query =
          Tag
          .define_window(:test).partition_by(:user_id)
          .define_window(:other_window).partition_by(:id)
          .to_sql

        expect(query).to end_with("WINDOW test AS (PARTITION BY user_id), other_window AS (PARTITION BY id)")
      end

      it "contains each windows order by statements" do
        query =
          Tag
          .define_window(:test).partition_by(:user_id, order_by: :id)
          .define_window(:other_window).partition_by(:id, order_by: { tags: :user_id })
          .to_sql

        expect(query).to end_with("WINDOW test AS (PARTITION BY user_id ORDER BY id), other_window AS (PARTITION BY id ORDER BY tags.user_id ASC)")
      end
    end
  end

  describe "#window_select" do
    let(:query_base)   { Tag.define_window(:w).partition_by(:user_id, order_by: :id) }
    let(:expected_end) { "WINDOW w AS (PARTITION BY user_id ORDER BY id)" }

    [:row_to_number, :rank, :dense_rank, :percent_rank, :cume_dist].each do |window_function|
      context "#{window_function.to_s.upcase}()" do # rubocop:disable RSpec/ContextWording
        let(:expected_function) { "#{window_function.to_s.upcase}()" }
        let(:query) do
          query_base.select_window(window_function, over: :w, as: :window_response).to_sql
        end

        it "appends the function to the select query" do
          expected_start = "SELECT (#{expected_function} OVER w) AS \"window_response\""
          expect(query).to start_with(expected_start).and(end_with(expected_end))
        end
      end
    end

    { ntile: 1, lag: 2, lead: 3, first_value: 1, last_value: 1, nth_value: 2 }.each_pair do |window_function, arg_count|
      context "#{window_function.to_s.upcase}/#{arg_count}" do # rubocop:disable RSpec/ContextWording
        let(:arguments)         { ["a", 1, :sauce].first(arg_count) }
        let(:expected_function) { "#{window_function.to_s.upcase}(#{arguments.join(', ')})" }
        let(:query) do
          query_base.select_window(window_function, *arguments, over: :w, as: :window_response).to_sql
        end

        it "appends the function to the select query" do
          expected_start = "SELECT (#{expected_function} OVER w) AS \"window_response\""
          expect(query).to start_with(expected_start).and(end_with(expected_end))
        end
      end
    end

    context "when not providing a partition by value" do
      it "constructs a window function" do
        query =
          Tag
          .define_window(:no_args).partition_by(order_by: { tag_number: :desc })
          .select_window(:row_number, over: :no_args, as: :my_row)
          .to_sql

        expect(query).to eq("SELECT (ROW_NUMBER() OVER no_args) AS \"my_row\" FROM \"tags\" WINDOW no_args AS (ORDER BY tag_number DESC)")
      end
    end
  end
end
