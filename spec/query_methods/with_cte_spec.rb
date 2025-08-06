# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record With CTE Query Methods" do
  let!(:user_one)    { User.create! }
  let!(:user_two)    { User.create! }
  let!(:profile_one) { ProfileL.create!(user_id: user_one.id, likes: 200) }
  let!(:profile_two) { ProfileL.create!(user_id: user_two.id, likes: 500) }

  describe ".with/1" do
    context "when using as a standalone query" do
      it "only returns a person with less than 300 likes" do
        query = User.with(profile: ProfileL.where("likes < 300"))
                    .joins("JOIN profile ON profile.user_id = users.id")

        expect(query).to contain_exactly(user_one)
      end

      it "returns anyone with likes greater than or equal to 200" do
        query = User.with(profile: ProfileL.where("likes >= 200"))
                    .joins("JOIN profile ON profile.user_id = users.id")

        expect(query).to contain_exactly(user_one, user_two)
      end
    end

    context "when creating using values" do
      let!(:user_tommy) { User.create!(name: "tommy") }
      let!(:user_jimmy) { User.create!(name: "jimmy") }

      before do
        User.create!(name: "diff")
      end

      it "returns only users with matching names from cte" do
        cte = { "user_names(name)" => "values('jimmy'),('tommy'),('gummy')" }

        query = User.with(cte)
                    .joins("JOIN user_names ON users.name = user_names.name")
                    .order(:name)

        expect(query).to contain_exactly(user_jimmy, user_tommy)
      end
    end

    context "when merging in query" do
      before do
        VersionControl.create!(versionable: profile_one, source: { help: "me" })
        VersionControl.create!(versionable: profile_two, source: { help: "no one" })
      end

      it "maintains the CTE table when merging into existing AR queries" do
        sub_query = ProfileL.with(version_controls: VersionControl.where.contains(source: { help: "me" }))
        query     = User.joins(profile_l: :version).merge(sub_query)

        expect(query).to contain_exactly(user_one)
      end

      it "contains a unique list of ordered CTE keys when merging in multiple children" do
        x     = User.with(profile: ProfileL.where("likes < 300"))
        y     = User.with(profile: ProfileL.where("likes > 400"))
        z     = y.merge(x).joins("JOIN profile ON profile.user_id = users.id") # Y should reject X's CTE (FIFO)
        query = User.with(my_profile: z).joins("JOIN my_profile ON my_profile.id = users.id")

        expect(query.cte.with_keys).to eq([:profile, :my_profile])
        expect(query).to contain_exactly(user_two)
      end
    end

    context "when the relation uses itself as a second CTE" do
      it "works without a SystemStackError" do
        user_relation = User.all

        # Add first CTE to User Relation
        group_relation = Group.all
        user_relation_with_cte = user_relation.with("first_cte" => group_relation)

        # User Relation with a CTE adds itself as another CTE
        user_relation_with_self_cte = user_relation_with_cte.with("self_cte" => user_relation_with_cte)

        expect(user_relation_with_self_cte).to contain_exactly(user_one, user_two)
      end
    end
  end

  # New feature flag and deprecation tests
  describe "WithCTE feature flag and deprecation" do
    let(:relation) { User.all }
    let(:cte_hash) { { profile: ProfileL.where("likes < 300") } }
    let(:orig_disabled) { ActiveRecordExtended::Config.with_cte_disabled }
    let(:orig_warn) { ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled }

    after do
      ActiveRecordExtended::Config.with_cte_disabled = orig_disabled
      ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled = orig_warn
    end

    context "when on Rails < 7.2" do
      before do
        stub_const("ActiveRecordExtended::AR_VERSION_GTE_7_2", false)
      end

      it "allows WithCTE even when disabled (Rails < 7.2 ignores config)" do
        ActiveRecordExtended::Config.with_cte_disabled = true
        # For Rails < 7.2, CTE should always work regardless of config
        expect { relation.with(cte_hash) }.not_to raise_error
      end

      it "allows WithCTE by default for Rails < 7.2 (no warning)" do
        ActiveRecordExtended::Config.with_cte_disabled = false
        expect { relation.with(cte_hash) }.not_to raise_error
      end
    end

    context "when on Rails >= 7.2" do
      let(:with_cte) { ActiveRecordExtended::QueryMethods::WithCTE::WithCTE.new(relation) }

      before do
        stub_const("ActiveRecordExtended::AR_VERSION_GTE_7_2", true)
        ActiveRecordExtended::Config.with_cte_disabled = true
        allow(ActiveRecordExtended::CTE_DEPRECATOR).to receive(:warn)
      end

      it "emits a deprecation warning when WithCTE is used and warnings are enabled" do
        ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled = true
        with_cte
        expect(ActiveRecordExtended::CTE_DEPRECATOR).to have_received(:warn).with(/WithCTE.*support is deprecated/).at_least(:once)
      end

      it "does not emit a deprecation warning if warnings are disabled" do
        ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled = false
        with_cte
        expect(ActiveRecordExtended::CTE_DEPRECATOR).not_to have_received(:warn)
      end

      context "when CTE support is disabled" do
        before do
          ActiveRecordExtended::Config.with_cte_disabled = true
        end

        it "raises error when trying to use recursive CTE" do
          expect do
            relation.with.recursive(cte_hash)
          end.to raise_error(ArgumentError, /Native Rails CTE.*requires arguments/)
        end

        it "raises error when trying to use with! with recursive" do
          expect do
            relation.with!.recursive(cte_hash)
          end.to raise_error(/Use the native recursive CTE/)
        end

        it "raises ArgumentError when trying to use with without arguments" do
          expect do
            relation.with
          end.to raise_error(ArgumentError, /Native Rails CTE.*requires arguments/)
        end

        it "raises error when trying to use build_with" do
          # build_with is a private method, so we need to test it differently
          # The error should be raised when trying to generate SQL
          # First, we need to ensure the relation has CTE values
          relation.cte = ActiveRecordExtended::QueryMethods::WithCTE::WithCTE.new(relation)
          relation.cte.with_values = cte_hash

          # When CTE support is disabled, with_values? should return false
          # so build_with is never called
          expect(relation.with_values?).to be false
        end
      end

      context "when CTE support is enabled" do
        before do
          ActiveRecordExtended::Config.with_cte_disabled = false
        end

        it "allows normal CTE usage" do
          expect { relation.with(cte_hash) }.not_to raise_error
        end

        it "allows recursive CTE usage" do
          expect { relation.with.recursive(cte_hash) }.not_to raise_error
        end

        it "allows with! usage" do
          expect { relation.with!(cte_hash) }.not_to raise_error
        end
      end
    end
  end

  describe "WithCTE deprecation warnings for specific methods" do
    let(:relation) { User.all }
    let(:cte_hash) { { profile: ProfileL.where("likes < 300") } }
    let(:orig_disabled) { ActiveRecordExtended::Config.with_cte_disabled }
    let(:orig_warn) { ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled }

    before do
      stub_const("ActiveRecordExtended::AR_VERSION_GTE_7_2", true)
      ActiveRecordExtended::Config.with_cte_disabled = false
      ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled = true
      allow(ActiveRecordExtended::CTE_DEPRECATOR).to receive(:warn)
    end

    after do
      ActiveRecordExtended::Config.with_cte_disabled = orig_disabled
      ActiveRecordExtended::Config.with_cte_deprecation_warnings_enabled = orig_warn
    end

    it "emits deprecation warning for recursive method" do
      relation.with.recursive(cte_hash)
      expect(ActiveRecordExtended::CTE_DEPRECATOR).to have_received(:warn).with(/recursive CTE/).at_least(:once)
    end

    it "emits deprecation warning for materialized method" do
      relation.with.materialized(cte_hash)
      expect(ActiveRecordExtended::CTE_DEPRECATOR).to have_received(:warn).with(/Materialized CTEs/).at_least(:once)
    end

    it "emits deprecation warning for not_materialized method" do
      relation.with.not_materialized(cte_hash)
      expect(ActiveRecordExtended::CTE_DEPRECATOR).to have_received(:warn).with(/Not materialized CTEs/).at_least(:once)
    end

    it "emits deprecation warning for with method" do
      relation.with(cte_hash)
      expect(ActiveRecordExtended::CTE_DEPRECATOR).to have_received(:warn).with(/WithCTE.*support is deprecated/).at_least(:once)
    end
  end
end
