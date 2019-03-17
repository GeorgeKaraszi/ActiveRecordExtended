# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Inet Query Methods" do
  describe "#inet_contained_within" do
    let!(:local_1)     { Person.create!(ip: "127.0.0.1") }
    let!(:local_44)    { Person.create!(ip: "127.0.0.44") }
    let!(:local_99_1)  { Person.create!(ip: "127.0.99.1") }
    let!(:local_range) { Person.create!(ip: "127.0.0.1/10") }

    it "Should return people who have an IP within the 127.0.0.1/24 range" do
      query = Person.where.inet_contained_within(ip: "127.0.0.1/24")
      expect(query).to include(local_1, local_44)
      expect(query).to_not include(local_99_1, local_range)
    end

    it "Should return all users who have an IP within the 127.0.0.1/16 range" do
      query = Person.where.inet_contained_within(ip: "127.0.0.1/16")
      expect(query).to include(local_1, local_44, local_99_1)
      expect(query).to_not include(local_range)
    end
  end

  describe "inet_contained_within_or_equals" do
    let!(:local_1)    { Person.create!(ip: "127.0.0.1/10") }
    let!(:local_44)   { Person.create!(ip: "127.0.0.44/32") }
    let!(:local_99_1) { Person.create!(ip: "127.0.99.1") }

    it "Should find records that contain a matching submask" do
      query = Person.where.inet_contained_within_or_equals(ip: "127.0.0.44/32")
      expect(query).to include(local_44)
      expect(query).to_not include(local_1, local_99_1)
    end

    it "Should find records that are within range of a given submask" do
      query = Person.where.inet_contained_within_or_equals(ip: "127.0.0.1/16")
      expect(query).to include(local_44, local_99_1)
      expect(query).to_not include(local_1)

      query = Person.where.inet_contained_within_or_equals(ip: "127.0.0.1/8")
      expect(query).to include(local_1, local_44, local_99_1)
    end
  end

  describe "#inet_contains_or_equals" do
    let!(:local_1)    { Person.create!(ip: "127.0.0.1/10") }
    let!(:local_44)   { Person.create!(ip: "127.0.0.44/24") }
    let!(:local_99_1) { Person.create!(ip: "127.0.99.1") }

    it "Should find records with submask ranges that contain a given IP" do
      query = Person.where.inet_contains_or_equals(ip: "127.0.255.255")
      expect(query).to include(local_1)
      expect(query).to_not include(local_44, local_99_1)

      query = Person.where.inet_contains_or_equals(ip: "127.0.0.255")
      expect(query).to include(local_1, local_44)
      expect(query).to_not include(local_99_1)
    end

    it "Finds records when querying with a submasked value" do
      query = Person.where.inet_contains_or_equals(ip: "127.0.0.1/10")
      expect(query).to include(local_1)
      expect(query).to_not include(local_44, local_99_1)

      query = Person.where.inet_contains_or_equals(ip: "127.0.0.1/32")
      expect(query).to include(local_1, local_44)
      expect(query).to_not include(local_99_1)
    end
  end

  describe "#inet_contains" do
    let!(:local_1)    { Person.create!(ip: "127.0.0.1/10") }
    let!(:local_44)   { Person.create!(ip: "127.0.0.44/24") }

    it "Should find records that the given IP falls within" do
      query = Person.where.inet_contains(ip: "127.0.0.1")
      expect(query).to include(local_1, local_44)
    end

    it "Should not find records when querying with a submasked value" do
      query = Person.where.inet_contains(ip: "127.0.0.0/8")
      expect(query).to be_empty
    end
  end

  describe "#inet_contains_or_is_contained_within" do
    let!(:local_1)    { Person.create!(ip: "127.0.0.1/24") }
    let!(:local_44)   { Person.create!(ip: "127.0.22.44/8") }
    let!(:local_99_1) { Person.create!(ip: "127.0.99.1") }

    it "should find records where the records contain the given IP" do
      query = Person.where.inet_contains_or_is_contained_within(ip: "127.0.255.80")
      expect(query).to include(local_44)
      expect(query).to_not include(local_1, local_99_1)

      query = Person.where.inet_contains_or_is_contained_within(ip: "127.0.0.80")
      expect(query).to include(local_1, local_44)
      expect(query).to_not include(local_99_1)
    end

    it "Should find records that the where query contains a valid range" do
      query = Person.where.inet_contains_or_is_contained_within(ip: "127.0.0.80/8")
      expect(query).to include(local_1, local_44, local_99_1)

      query = Person.where.inet_contains_or_is_contained_within(ip: "127.0.0.80/16")
      expect(query).to include(local_1, local_44, local_99_1)
    end
  end
end
