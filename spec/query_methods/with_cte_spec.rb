# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record With CTE Query Methods" do
  let!(:person_one)  { Person.create! }
  let!(:person_two)  { Person.create! }
  let!(:profile_one) { ProfileL.create!(person_id: person_one.id, likes: 200) }
  let!(:profile_two) { ProfileL.create!(person_id: person_two.id, likes: 500) }

  describe ".with/1" do
    context "when using as a standalone query" do
      it "should only return a person with less than 300 likes" do
        query = Person.with(profile: ProfileL.where("likes < 300"))
                      .joins("JOIN profile ON profile.id = people.id")

        expect(query).to match_array([person_one])
      end

      it "should return anyone with likes greater than or equal to 200" do
        query = Person.with(profile: ProfileL.where("likes >= 200"))
                      .joins("JOIN profile ON profile.id = people.id")

        expect(query).to match_array([person_one, person_two])
      end
    end

    context "when merging in query" do
      let!(:version_one) { VersionControl.create!(versionable: profile_one, source: { help: "me" }) }
      let!(:version_two) { VersionControl.create!(versionable: profile_two, source: { help: "no one" }) }

      it "will maintain the CTE table when merging into existing AR queries" do
        sub_query = ProfileL.with(version_controls: VersionControl.where.contains(source: { help: "me" }))
        query     = Person.joins(profile_l: :version).merge(sub_query)

        expect(query).to match_array([person_one])
      end
    end
  end
end
