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

        expect(query).to match_array([user_one])
      end

      it "returns anyone with likes greater than or equal to 200" do
        query = User.with(profile: ProfileL.where("likes >= 200"))
                    .joins("JOIN profile ON profile.user_id = users.id")

        expect(query).to match_array([user_one, user_two])
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

        expect(query).to match_array([user_jimmy, user_tommy])
      end
    end

    context "when merging in query" do
      before do
        VersionControl.create!(versionable: profile_one, source: { help: "me" })
        VersionControl.create!(versionable: profile_two, source: { help: "no one" })
      end

      it "will maintain the CTE table when merging into existing AR queries" do
        sub_query = ProfileL.with(version_controls: VersionControl.where.contains(source: { help: "me" }))
        query     = User.joins(profile_l: :version).merge(sub_query)

        expect(query).to match_array([user_one])
      end

      it "contains a unique list of ordered CTE keys when merging in multiple children" do
        x     = User.with(profile: ProfileL.where("likes < 300"))
        y     = User.with(profile: ProfileL.where("likes > 400"))
        z     = y.merge(x).joins("JOIN profile ON profile.user_id = users.id") # Y should reject X's CTE (FIFO)
        query = User.with(my_profile: z).joins("JOIN my_profile ON my_profile.id = users.id")

        expect(query.cte.with_keys).to eq([:profile, :my_profile])
        expect(query).to match_array([user_two])
      end
    end
  end
end
