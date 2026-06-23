# frozen_string_literal: true

require "spec_helper"

RSpec.describe "CTE handler toggling" do
  let!(:user_one) { User.create! }
  let!(:user_two) { User.create! }

  before do
    ProfileL.create!(user_id: user_one.id, likes: 200)
    ProfileL.create!(user_id: user_two.id, likes: 500)
  end

  after do
    ActiveRecordExtended.config.cte_handler = :extended
    Thread.current[ActiveRecordExtended::THREAD_NATIVE_CTE_KEY] = nil
  end

  def build_query
    User.with(profile: ProfileL.where("likes < 300"))
        .joins("JOIN profile ON profile.user_id = users.id")
  end

  describe "default behavior" do
    it "defaults to the :extended handler" do
      expect(ActiveRecordExtended.config.cte_handler).to eq(:extended)
    end

    it "uses the gem's CTE storage" do
      query = build_query
      expect(query.with_values?).to be(true)
      expect(query).to contain_exactly(user_one)
    end

    # Mirror of the native proof: gem's own builder runs, Rails' does not.
    it "builds the CTE through the gem's builder, not Rails' native one" do
      expect_any_instance_of(ActiveRecordExtended::QueryMethods::WithCTE) # rubocop:disable RSpec/AnyInstance
        .to receive(:add_materialized_modifier).at_least(:once).and_call_original
      expect_any_instance_of(ActiveRecord::Relation) # rubocop:disable RSpec/AnyInstance
        .not_to receive(:build_with_value_from_hash)

      build_query.to_sql
    end
  end

  describe "global :native handler" do
    it "delegates `.with` to Rails native storage" do
      ActiveRecordExtended.config.cte_handler = :native

      query = build_query
      expect(query.with_values?).to be(false) # gem storage untouched
      expect(query.values[:with]).to be_present # native storage populated
      expect(query).to contain_exactly(user_one)
    end

    it "still produces a WITH statement in SQL" do
      ActiveRecordExtended.config.cte_handler = :native
      expect(build_query.to_sql).to match(/\AWITH/i)
    end

    # `build_with_value_from_hash` exists only in Rails' QueryMethods, never in
    # this gem. If it runs, the CTE was unmistakably built by Rails' own code.
    it "builds the CTE through Rails' native builder, not the gem's" do
      ActiveRecordExtended.config.cte_handler = :native

      expect_any_instance_of(ActiveRecord::Relation) # rubocop:disable RSpec/AnyInstance
        .to receive(:build_with_value_from_hash).at_least(:once).and_call_original
      expect_any_instance_of(ActiveRecordExtended::QueryMethods::WithCTE) # rubocop:disable RSpec/AnyInstance
        .not_to receive(:add_materialized_modifier)

      build_query.to_sql
    end
  end

  describe ".with_native_cte block" do
    it "forces native handling only inside the block" do
      native_query = ActiveRecordExtended.with_native_cte { build_query }
      expect(native_query.with_values?).to be(false)
      expect(native_query.values[:with]).to be_present

      extended_query = build_query
      expect(extended_query.with_values?).to be(true)
    end

    it "covers nested subquery `.with` built inside the block" do
      query = ActiveRecordExtended.with_native_cte do
        sub = User.with(inner: ProfileL.where("likes < 300"))
        User.with(outer: sub)
      end

      expect(query.with_values?).to be(false)
      expect(query.values[:with]).to be_present
    end

    it "restores the previous override when nested" do
      ActiveRecordExtended.with_native_cte do
        ActiveRecordExtended.with_extended_cte do
          expect(build_query.with_values?).to be(true)
        end
        expect(build_query.with_values?).to be(false)
      end
    end

    it "resets the override even when the block raises" do
      expect do
        ActiveRecordExtended.with_native_cte { raise "boom" }
      end.to raise_error("boom")

      expect(build_query.with_values?).to be(true)
    end
  end

  describe ".with_extended_cte block" do
    it "forces gem handling inside the block even when global is :native" do
      ActiveRecordExtended.config.cte_handler = :native

      query = ActiveRecordExtended.with_extended_cte { build_query }
      expect(query.with_values?).to be(true)
    end
  end

  describe "configuration validation" do
    it "rejects unknown handlers" do
      expect { ActiveRecordExtended.config.cte_handler = :bogus }
        .to raise_error(ArgumentError, /cte_handler must be one of/)
    end
  end
end
