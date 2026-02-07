# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Hash Related Query Methods" do
  let!(:one)   { User.create!(data: { nickname: "george" }, jsonb_data: { payment: "zip" }) }
  let!(:two)   { User.create!(data: { nickname: "dan"    }, jsonb_data: { payment: "zipper" }) }
  let!(:three) { User.create!(data: { nickname: "georgey" }) }

  describe "#contains" do
    context "with HStore Column Type" do
      it "returns records that contain hash elements in joined tables" do
        tag_one = Tag.create!(user_id: one.id)
        tag_two = Tag.create!(user_id: two.id)

        query = Tag.joins(:user).where.contains(users: { data: { nickname: "george" } })
        expect(query).to include(tag_one)
        expect(query).not_to include(tag_two)
      end

      it "returns records that contain hash value" do
        query = User.where.contains(data: { nickname: "george" })
        expect(query).to include(one)
        expect(query).not_to include(two, three)
      end
    end

    context "with JSONB Column Type" do
      it "returns records that contains a json hashed value" do
        query = User.where.contains(jsonb_data: { payment: "zip" })
        expect(query).to include(one)
        expect(query).not_to include(two, three)
      end

      it "returns records that contain jsonb elements in joined tables" do
        tag_one = Tag.create!(user_id: one.id)
        tag_two = Tag.create!(user_id: two.id)

        query = Tag.joins(:user).where.contains(users: { jsonb_data: { payment: "zip" } })
        expect(query).to include(tag_one)
        expect(query).not_to include(tag_two)
      end
    end
  end

  describe "#contains_key" do
    context "with HStore Column Type" do
      it "returns records that contain the hash key in joined tables" do
        four = User.create!(data: { alias: "four" })

        query = Tag.joins(:user).where.contains_key(users: { data: "nickname" })
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end

      it "returns records that contain the hash key" do
        four = User.create!(data: { alias: "four" })

        query = User.where.contains_key(data: "nickname")
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end
    end

    context "with JSONB Column Type" do
      it "returns records that contain the hash key in joined tables" do
        four = User.create!(jsonb_data: { alias: "four" })

        query = Tag.joins(:user).where.contains_key(users: { jsonb_data: "nickname" })
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end

      it "returns records that contain the hash key" do
        four = User.create!(jsonb_data: { alias: "four" })

        query = User.where.contains_key(jsonb_data: "nickname")
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end
    end
  end

  describe "#contains_any_key" do
    context "with HStore Column Type" do
      it "returns records that contain the hash key in joined tables" do
        four = User.create!(data: { alias: "four" })

        query = Tag.joins(:user).where.contains_any_key(users: { data: ["nickname"] })
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end

      it "returns records that contain the hash key" do
        four = User.create!(data: { alias: "four" })

        query = User.where.contains_any_key(data: ["nickname"])
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end
    end

    context "with JSONB Column Type" do
      it "returns records that contain the hash key in joined tables" do
        four = User.create!(jsonb_data: { alias: "four" })

        query = Tag.joins(:user).where.contains_any_key(users: { jsonb_data: ["nickname"] })
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end

      it "returns records that contain the hash key" do
        four = User.create!(jsonb_data: { alias: "four" })

        query = User.where.contains_any_key(jsonb_data: ["nickname"])
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end
    end
  end

  describe "#contains_all_keys" do
    context "with HStore Column Type" do
      it "returns records that contain the hash key in joined tables" do
        four = User.create!(data: { alias: "four" })

        query = Tag.joins(:user).where.contains_all_keys(users: { data: ["nickname"] })
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end

      it "returns records that contain the hash key" do
        four = User.create!(data: { alias: "four" })

        query = User.where.contains_all_keys(data: ["nickname"])
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end
    end

    context "with JSONB Column Type" do
      it "returns records that contain the hash key in joined tables" do
        four = User.create!(jsonb_data: { alias: "four" })

        query = Tag.joins(:user).where.contains_all_keys(users: { jsonb_data: ["nickname"] })
        expect(query).to include(one, two, three)
        expect(query).not_to include(four)
      end

      it "returns records that contain the hash key" do
        four = User.create!(jsonb_data: { nickname: "george", alias: "four" })

        query = User.where.contains_all_keys(jsonb_data: ["nickname", "alias"])
        expect(query).to include(four)
        expect(query).not_to include(one, two, three)
      end
    end
  end
end
