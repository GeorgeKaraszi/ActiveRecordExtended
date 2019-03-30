# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Either Methods" do
  let!(:one)       { User.create! }
  let!(:two)       { User.create! }
  let!(:three)     { User.create! }
  let!(:profile_l) { ProfileL.create!(user_id: one.id, likes: 100) }
  let!(:profile_r) { ProfileR.create!(user_id: two.id, dislikes: 50) }

  describe ".either_join/2" do
    it "Should only only return records that belong to profile L or profile R" do
      query = User.either_join(:profile_l, :profile_r)
      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    context "Alias .either_joins/2" do
      it "Should only only return records that belong to profile L or profile R" do
        query = User.either_joins(:profile_l, :profile_r)
        expect(query).to include(one, two)
        expect(query).to_not include(three)
      end
    end
  end

  describe ".either_order/2" do
    it "Should not exclude anyone who does not have a relationship" do
      query = User.either_order(:asc, profile_l: :likes, profile_r: :dislikes)
      expect(query.count).to eq(3)
      expect(query[0]).to eq(two)
      expect(query[1]).to eq(one)
      expect(query[2]).to eq(three)
    end

    it "Should order users based on their likes and dislikes in ascended order" do
      query = User.either_order(:asc, profile_l: :likes, profile_r: :dislikes).where(id: [one.id, two.id])
      expect(query.count).to eq(2)
      expect(query.first).to eq(two)
      expect(query.last).to eq(one)
    end

    it "Should order users based on their likes and dislikes in descending order" do
      query = User.either_order(:desc, profile_l: :likes, profile_r: :dislikes).where(id: [one.id, two.id])
      expect(query.first).to eq(one)
      expect(query.last).to eq(two)
    end

    context "Alias .either_order/2" do
      it "Should order users based on their likes and dislikes in ascended order" do
        query = User.either_orders(:asc, profile_l: :likes, profile_r: :dislikes).where(id: [one.id, two.id])
        expect(query.count).to eq(2)
        expect(query.first).to eq(two)
        expect(query.last).to eq(one)
      end
    end
  end
end
