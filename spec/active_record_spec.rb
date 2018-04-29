# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Querying" do
  describe "#overlap" do
    it "Should return matched records" do
      one   = Person.create!(tags: [1, 2])
      two   = Person.create!(tags: [2, 3])
      three = Person.create!(tags: [3, 4])
      query = Person.where.overlap(tags: [2])

      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end
  end
end
