# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Any / None of Methods" do
  let!(:one)       { User.create!(personal_id: 1) }
  let!(:two)       { User.create!(personal_id: 2) }
  let!(:three)     { User.create!(personal_id: 3) }

  let!(:tag_one)   { Tag.create!(user_id: one.id) }
  let!(:tag_two)   { Tag.create!(user_id: two.id) }
  let!(:tag_three) { Tag.create!(user_id: three.id) }

  describe "where.any_of/1" do
    it "Should return queries that match any of the outlined queries" do
      query = User.where.any_of({ personal_id: 1 }, { personal_id: 2 })
      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    it "Should accept where query predicates" do
      personal_one = User.where(personal_id: 1)
      personal_two = User.where(personal_id: 2)
      query = User.where.any_of(personal_one, personal_two)

      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    it "Should accept query strings" do
      personal_one = User.where(personal_id: 1)

      query = User.where.any_of(personal_one, "personal_id > 2")
      expect(query).to include(one, three)
      expect(query).to_not include(two)

      query = User.where.any_of(["personal_id >= ?", 2])
      expect(query).to include(two, three)
      expect(query).to_not include(one)
    end

    context "Relationship queries" do
      it "Finds records that are queried from two or more has_many associations" do
        user_one_tag = Tag.create!(user_id: one.id)
        user_two_tag = Tag.create!(user_id: two.id)
        query = Tag.where.any_of(one.hm_tags, two.hm_tags)

        expect(query).to include(tag_one, tag_two, user_one_tag, user_two_tag)
        expect(query).to_not include(tag_three)
      end

      it "Finds records that are dynamically joined" do
        user_one_tag = Tag.where(users: { id: one.id }).includes(:user).references(:user)
        user_two_tag = Tag.where(users: { id: two.id }).joins(:user)
        query = Tag.where.any_of(user_one_tag, user_two_tag)

        expect(query).to include(tag_one, tag_two)
        expect(query).to_not include(tag_three)
      end

      it "Return matched records of a joined table on the parent level" do
        query = Tag.joins(:user).where.any_of(
          { users: { personal_id: 1 } },
          { users: { personal_id: 3 } },
        )

        expect(query).to include(tag_one, tag_three)
        expect(query).to_not include(tag_two)
      end
    end
  end

  describe "where.none_of/1" do
    it "Should return queries that match none of the outlined queries" do
      query = User.where.none_of({ personal_id: 1 }, { personal_id: 2 })
      expect(query).to include(three)
      expect(query).to_not include(one, two)
    end

    it "Should accept where query predicates" do
      personal_one = User.where(personal_id: 1)
      personal_two = User.where(personal_id: 2)
      query = User.where.none_of(personal_one, personal_two)

      expect(query).to include(three)
      expect(query).to_not include(one, two)
    end

    it "Should accept query strings" do
      personal_one = User.where(personal_id: 1)

      query = User.where.none_of(personal_one, "personal_id > 2")
      expect(query).to include(two)
      expect(query).to_not include(one, three)

      query = User.where.none_of(["personal_id >= ?", 2])
      expect(query).to include(one)
      expect(query).to_not include(two, three)
    end

    context "Relationship queries" do
      it "Finds records that are queried from two or more has_many associations" do
        user_one_tag = Tag.create!(user_id: one.id)
        user_two_tag = Tag.create!(user_id: two.id)
        query = Tag.where.none_of(one.hm_tags, two.hm_tags)

        expect(query).to include(tag_three)
        expect(query).to_not include(tag_one, tag_two, user_one_tag, user_two_tag)
      end

      it "Finds records that are dynamically joined" do
        user_one_tag = Tag.where(users: { id: one.id }).includes(:user).references(:user)
        user_two_tag = Tag.where(users: { id: two.id }).joins(:user)
        query = Tag.where.none_of(user_one_tag, user_two_tag)

        expect(query).to include(tag_three)
        expect(query).to_not include(tag_one, tag_two)
      end

      it "Return matched records of a joined table on the parent level" do
        query = Tag.joins(:user).where.none_of(
          { users: { personal_id: 1 } },
          { users: { personal_id: 3 } },
        )

        expect(query).to include(tag_two)
        expect(query).to_not include(tag_one, tag_three)
      end
    end
  end
end
