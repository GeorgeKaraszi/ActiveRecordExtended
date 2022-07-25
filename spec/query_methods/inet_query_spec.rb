# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Inet Query Methods" do
  before { stub_const("User", Namespaced::Record) }

  describe "#inet_contained_within" do
    let!(:local_1)     { User.create!(ip: "127.0.0.1") }
    let!(:local_44)    { User.create!(ip: "127.0.0.44") }
    let!(:local_99_1)  { User.create!(ip: "127.0.99.1") }
    let!(:local_range) { User.create!(ip: "127.0.0.1/10") }

    it "returns users who have an IP within the 127.0.0.1/24 range" do
      query = User.where.inet_contained_within(ip: "127.0.0.1/24")
      expect(query).to include(local_1, local_44)
      expect(query).not_to include(local_99_1, local_range)
    end

    it "returns all users who have an IP within the 127.0.0.1/16 range" do
      query = User.where.inet_contained_within(ip: "127.0.0.1/16")
      expect(query).to include(local_1, local_44, local_99_1)
      expect(query).not_to include(local_range)
    end
  end

  describe "inet_contained_within_or_equals" do
    let!(:local_1)    { User.create!(ip: "127.0.0.1/10") }
    let!(:local_44)   { User.create!(ip: "127.0.0.44/32") }
    let!(:local_99_1) { User.create!(ip: "127.0.99.1") }

    it "finds records that contain a matching submask" do
      query = User.where.inet_contained_within_or_equals(ip: "127.0.0.44/32")
      expect(query).to include(local_44)
      expect(query).not_to include(local_1, local_99_1)
    end

    it "finds records that are within range of a given submask" do
      query = User.where.inet_contained_within_or_equals(ip: "127.0.0.1/16")
      expect(query).to include(local_44, local_99_1)
      expect(query).not_to include(local_1)

      query = User.where.inet_contained_within_or_equals(ip: "127.0.0.1/8")
      expect(query).to include(local_1, local_44, local_99_1)
    end
  end

  describe "#inet_contains_or_equals" do
    let!(:local_1)    { User.create!(ip: "127.0.0.1/10") }
    let!(:local_44)   { User.create!(ip: "127.0.0.44/24") }
    let!(:local_99_1) { User.create!(ip: "127.0.99.1") }

    it "finds records with submask ranges that contain a given IP" do
      query = User.where.inet_contains_or_equals(ip: "127.0.255.255")
      expect(query).to include(local_1)
      expect(query).not_to include(local_44, local_99_1)

      query = User.where.inet_contains_or_equals(ip: "127.0.0.255")
      expect(query).to include(local_1, local_44)
      expect(query).not_to include(local_99_1)
    end

    it "Finds records when querying with a submasked value" do
      query = User.where.inet_contains_or_equals(ip: "127.0.0.1/10")
      expect(query).to include(local_1)
      expect(query).not_to include(local_44, local_99_1)

      query = User.where.inet_contains_or_equals(ip: "127.0.0.1/32")
      expect(query).to include(local_1, local_44)
      expect(query).not_to include(local_99_1)
    end
  end

  describe "#inet_contains" do
    let!(:local_1)    { User.create!(ip: "127.0.0.1/10") }
    let!(:local_44)   { User.create!(ip: "127.0.0.44/24") }

    it "finds records that the given IP falls within" do
      query = User.where.inet_contains(ip: "127.0.0.1")
      expect(query).to include(local_1, local_44)
    end

    it "does not find records when querying with a submasked value" do
      query = User.where.inet_contains(ip: "127.0.0.0/8")
      expect(query).to be_empty
    end
  end

  describe "#inet_contains_or_is_contained_within" do
    let!(:local_1)    { User.create!(ip: "127.0.0.1/24") }
    let!(:local_44)   { User.create!(ip: "127.0.22.44/8") }
    let!(:local_99_1) { User.create!(ip: "127.0.99.1") }

    it "finds records where the records contain the given IP" do
      query = User.where.inet_contains_or_is_contained_within(ip: "127.0.255.80")
      expect(query).to include(local_44)
      expect(query).not_to include(local_1, local_99_1)

      query = User.where.inet_contains_or_is_contained_within(ip: "127.0.0.80")
      expect(query).to include(local_1, local_44)
      expect(query).not_to include(local_99_1)
    end

    it "finds records that the where query contains a valid range" do
      query = User.where.inet_contains_or_is_contained_within(ip: "127.0.0.80/8")
      expect(query).to include(local_1, local_44, local_99_1)

      query = User.where.inet_contains_or_is_contained_within(ip: "127.0.0.80/16")
      expect(query).to include(local_1, local_44, local_99_1)
    end
  end
end
