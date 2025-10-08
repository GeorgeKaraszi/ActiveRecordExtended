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

  describe "WithCTE Deprecations", skip: !ActiveRecordExtended::AR_VERSION_GTE_7_2 do
    after do
      ActiveRecordExtended::Config.configure do |config|
        config.cte_deprecation_warnings = false
        config.cte_migration_tracking = false
        config.cte_adapter_mode = :legacy
        config.cte_usage_callback = nil
      end
    end

    describe "#with_native" do
      let(:relation) { User.all }

      before do
        ActiveRecordExtended::Config.cte_adapter_mode = :legacy
        allow(relation).to receive(:legacy_with).and_call_original
      end

      it "does not use legacy_with when forced to use native implementation" do
        relation
          .with_native(profile: ProfileL.where("likes < 300"))
          .with(other_profile: ProfileL.where("likes < 300"))

        expect(relation).not_to have_received(:legacy_with)
      end

      it "does use legacy_with if not forced to use native" do
        relation
          .with(profile: ProfileL.where("likes < 300"))
          .with(other_profile: ProfileL.where("likes < 300"))
        expect(relation).to have_received(:legacy_with).twice
      end
    end

    describe "ActiveRecordExtended::Config.cte_deprecation_warnings" do
      before { ActiveRecordExtended::Config.cte_deprecation_warnings = true }

      it "warns when using .with" do
        allow(ActiveRecordExtended::CTE_DEPRECATOR).to receive(:warn)
        User.with(profile: ProfileL.where("likes < 300"))
        expect(ActiveRecordExtended::CTE_DEPRECATOR).to have_received(:warn).with(
          /CTE support will be deprecated in the next major release/
        ).at_least(:once)
      end
    end

    describe "ActiveRecordExtended::Config.cte_usage_callback" do
      before do
        ActiveRecordExtended::Config.cte_migration_tracking = true
        ActiveRecordExtended::Config.cte_usage_callback = -> {}
      end

      it "calls the callback proc" do
        allow(ActiveRecordExtended::Config.cte_usage_callback).to receive(:call)
        User.with(profile: ProfileL.where("likes < 300"))
        expect(ActiveRecordExtended::Config.cte_usage_callback).to have_received(:call).with(
          method:    :with,
          locations: be_a(Array),
          timestamp: be_a(Time)
        ).at_least(:once)
      end
    end

    describe "ActiveRecordExtended::Config.cte_adapter_mode" do
      let(:relation) { User.all }

      before do
        allow(relation).to receive(:with).and_call_original
        allow(relation).to receive(:legacy_with).and_call_original
      end

      context "when :legacy" do
        before { ActiveRecordExtended::Config.cte_adapter_mode = :legacy }

        it "uses the legacy methods" do
          relation.with(profile: ProfileL.where("likes < 300"))
          expect(relation).to have_received(:with)
          expect(relation).to have_received(:legacy_with)
        end
      end

      context "when :native" do
        before { ActiveRecordExtended::Config.cte_adapter_mode = :native }

        it "uses the only native Rails methods" do
          relation.with(profile: ProfileL.where("likes < 300"))
          expect(relation).to have_received(:with)
          expect(relation).not_to have_received(:legacy_with)
        end
      end
    end
  end
end
