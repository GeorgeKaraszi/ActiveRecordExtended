# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Either Methods" do
  let!(:one)       { Person.create! }
  let!(:two)       { Person.create! }
  let!(:three)     { Person.create! }
  let!(:profile_l) { ProfileL.create!(person_id: one.id, likes: 100) }
  let!(:profile_r) { ProfileR.create!(person_id: two.id, dislikes: 50) }

  describe ".either_join/2" do
    it "Should only only return records that belong to profile L or profile R" do
      query = Person.either_join(:profile_l, :profile_r)
      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    context "Alias .either_joins/2" do
      it "Should only only return records that belong to profile L or profile R" do
        query = Person.either_joins(:profile_l, :profile_r)
        expect(query).to include(one, two)
        expect(query).to_not include(three)
      end
    end
  end

  describe ".either_order/2" do
    it "Should not exclude anyone who does not have a relationship" do
      query = Person.either_order(:asc, profile_l: :likes, profile_r: :dislikes)
      expect(query).to include(one, two, three)
    end

    it "Should order people based on their likes and dislikes in ascended order" do
      query = Person.either_order(:asc, profile_l: :likes, profile_r: :dislikes).where(id: [one.id, two.id])
      expect(query).to match_array([two, one])
    end

    it "Should order people based on their likes and dislikes in descending order" do
      query = Person.either_order(:desc, profile_l: :likes, profile_r: :dislikes).where(id: [one.id, two.id])
      expect(query).to match_array([one, two])
    end

    context "Alias .either_order/2" do
      it "Should order people based on their likes and dislikes in ascended order" do
        query = Person.either_orders(:asc, profile_l: :likes, profile_r: :dislikes).where(id: [one.id, two.id])
        expect(query).to match_array([two, one])
      end
    end
  end
end
