# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Hash Related Query Methods" do
  let!(:one)   { User.create!(data: { nickname: "george" }, jsonb_data: { payment: "zip" }) }
  let!(:two)   { User.create!(data: { nickname: "dan"    }, jsonb_data: { payment: "zipper" }) }
  let!(:three) { User.create!(data: { nickname: "georgey" }) }

  describe "#contains" do
    context "HStore Column Type" do
      it "returns records that contain hash elements in joined tables" do
        tag_one = Tag.create!(user_id: one.id)
        tag_two = Tag.create!(user_id: two.id)

        query = Tag.joins(:user).where.contains(users: { data: { nickname: "george" } })
        expect(query).to include(tag_one)
        expect(query).to_not include(tag_two)
      end

      it "returns records that contain hash value" do
        query = User.where.contains(data: { nickname: "george" })
        expect(query).to include(one)
        expect(query).to_not include(two, three)
      end
    end

    context "JSONB Column Type" do
      it "returns records that contains a json hashed value" do
        query = User.where.contains(jsonb_data: { payment: "zip" })
        expect(query).to include(one)
        expect(query).to_not include(two, three)
      end

      it "returns records that contain jsonb elements in joined tables" do
        tag_one = Tag.create!(user_id: one.id)
        tag_two = Tag.create!(user_id: two.id)

        query = Tag.joins(:user).where.contains(users: { jsonb_data: { payment: "zip" } })
        expect(query).to include(tag_one)
        expect(query).to_not include(tag_two)
      end
    end
  end
end
