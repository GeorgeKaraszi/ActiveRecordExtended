# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Array Query Methods" do
  let!(:one)   { User.create!(tags: [1, 2, 3],  personal_id: 33) }
  let!(:two)   { User.create!(tags: [3, 1, 5],  personal_id: 88) }
  let!(:three) { User.create!(tags: [2, 8, 20], personal_id: 33) }

  describe "#overlap" do
    it "Should return matched records" do
      query = User.where.overlap(tags: [1])
      expect(query).to include(one, two)
      expect(query).to_not include(three)

      query = User.where.overlap(tags: [2, 3])
      expect(query).to include(one, two, three)
    end
  end

  describe "#contains" do
    it "returns records that contain elements in an array" do
      query = User.where.contains(tags: [1, 3])
      expect(query).to include(one, two)
      expect(query).to_not include(three)

      query = User.where.contains(tags: [8, 2])
      expect(query).to include(three)
      expect(query).to_not include(one, two)
    end
  end

  describe "#any" do
    it "should return any records that match" do
      query = User.where.any(tags: 3)
      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    it "allows chaining" do
      query = User.where.any(tags: 3).where(personal_id: 33)
      expect(query).to include(one)
      expect(query).to_not include(two, three)
    end
  end

  describe "#all" do
    let!(:contains_all)     { User.create!(tags: [1], personal_id: 1) }
    let!(:contains_all_two) { User.create!(tags: [1], personal_id: 2) }
    let!(:contains_some)    { User.create!(tags: [1, 2], personal_id: 2) }

    it "should return any records that match" do
      query = User.where.all(tags: 1)
      expect(query).to include(contains_all, contains_all_two)
      expect(query).to_not include(contains_some)
    end

    it "allows chaining" do
      query = User.where.all(tags: 1).where(personal_id: 1)
      expect(query).to include(contains_all)
      expect(query).to_not include(contains_all_two, contains_some)
    end
  end
end
