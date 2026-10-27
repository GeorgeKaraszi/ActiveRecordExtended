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

      it "does not clear the CTEs of a merged recursive query" do
        recursive_query = User.with.recursive(recursive_users: User.where(id: user_one.id))
        User.all.merge(recursive_query).to_sql

        expect(recursive_query.cte.with_keys).to eq([:recursive_users])
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

    context "when called again will spawn the relation" do
      let(:cte_hash) { { profile: ProfileL.where("likes < 300") } }
      let(:relation) { User.all.with(cte_hash) }

      it "maintains the CTE in the spawned relation" do
        expect(relation.all.to_sql).to eq(relation.to_sql)
      end

      it "does not change the original relation when a spawned relation adds a CTE" do
        relation.all.with!(other: ProfileL.where("likes > 400"))

        expect(relation.cte.with_values.keys).to eq([:profile])
      end

      it "does not change the original relation when a chained relation adds a materialized CTE" do
        materialized_relation = relation.with.materialized(cte_hash)

        expect(relation.cte.materialized_key?(:profile)).to be(false)
        expect(materialized_relation.cte.materialized_key?(:profile)).to be(true)
      end

      it "does not change relations that share a CTE when one of them is nested" do
        child = ProfileL.with(inner: ProfileL.where("likes < 300"))
        sibling = child.where(likes: 200)
        User.with(outer: sibling).to_sql

        expect(child.cte.with_keys).to eq([:inner])
      end

      it "does not change relations that share a CTE when one of them is in a union" do
        child = User.with(profile: ProfileL.where("likes < 300")).where(id: user_one.id)
        sibling = child.where(id: user_one.id)
        User.union(User.where(id: user_two.id), sibling).to_sql

        expect(child.cte.with_keys).to eq([:profile])
      end
    end
  end

  describe "WithCTE#dup" do
    it "does not share state with the original" do
      original = ActiveRecordExtended::QueryMethods::WithCTE::WithCTE.new(User.all)
      original.pipe_cte_with!(profile: ProfileL.all)
      copy = original.dup

      copy.pipe_cte_with!(other: ProfileL.all)
      copy.materialized_keys << :profile
      copy.not_materialized_keys << :other

      expect(original.with_keys).to eq([:profile])
      expect(original.materialized_keys).to be_empty
      expect(original.not_materialized_keys).to be_empty
    end
  end
end
