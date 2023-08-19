# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Combine in Relation" do
  let!(:user_one)       { User.create! }
  let!(:user_two)       { User.create! }
  let!(:user_three)       { User.create! }
  let!(:group_one)       { Group.create! }
  let!(:group_two)       { Group.create! }
  let!(:group_three)       { Group.create! }
  let!(:groups_user_one)     { GroupsUser.create!(user_id: user_one.id, group_id: group_one.id) }
  let!(:groups_user_two)     { GroupsUser.create!(user_id: user_two.id, group_id: group_two.id) }
  let!(:groups_user_three)     { GroupsUser.create!(user_id: user_three.id, group_id: group_three.id) }

  describe ".combine_with_in/2" do
    it "combines two scopes into an IN statement" do
      query = GroupsUser.for_users(user_one.id).for_users(user_two.id)
      expect(query.to_sql).to include("\"groups_users\".\"user_id\" IN (#{user_one.id}, #{user_two.id})")

      expect(query).to include(groups_user_one, groups_user_two)
      expect(query).not_to include(groups_user_three)
    end

    it "does an AND if there are two different scopes with only one of each scope" do
      query = GroupsUser.for_users(user_one.id).for_group(group_one.id)
      expect(query.to_sql).to include("\"groups_users\".\"user_id\" = #{user_one.id} AND \"groups_users\".\"group_id\" = #{group_one.id}")

      expect(query).to include(groups_user_one)
      expect(query).not_to include(groups_user_two)
    end

    it "does an AND and IN if there are two different scopes with one having two of them" do
      query = GroupsUser.for_users(user_one.id).for_group(group_one.id).for_users(user_two.id)
      expect(query.to_sql).to include("\"groups_users\".\"user_id\" IN (#{user_one.id}, #{user_two.id}) AND \"groups_users\".\"group_id\" = #{group_one.id}")

      expect(query).to include(groups_user_one)
      expect(query).not_to include(groups_user_two)
    end

    it "does an AND and IN if there are one scope with two statements and one outside statement" do
      query = GroupsUser.where(id: groups_user_one).for_users(user_one.id).for_users(user_two.id)
      expect(query.to_sql).to include("\"groups_users\".\"id\" = #{groups_user_one.id} AND \"groups_users\".\"user_id\" IN (#{user_one.id}, #{user_two.id})")

      expect(query).to include(groups_user_one)
      expect(query).not_to include(groups_user_two)
    end

    it "has multiple AND and one IN if there are one scope with two statements and two outside statement" do
      query = GroupsUser.where(id: groups_user_one).where(group_id: group_one.id).for_users(user_one.id).for_users(user_two.id)
      expect(query.to_sql).to include("\"groups_users\".\"id\" = #{groups_user_one.id} AND \"groups_users\".\"group_id\" = #{group_one.id} AND \"groups_users\".\"user_id\" IN (#{user_one.id}, #{user_two.id})")

      expect(query).to include(groups_user_one)
      expect(query).not_to include(groups_user_two)
    end

    it "has one IN if there are one scope with two statements but one of them having an array" do
      query = GroupsUser.for_users(id: [user_one, user_two]).for_users(user_three.id)
      expect(query.to_sql).to include("\"groups_users\".\"user_id\" IN (#{user_one.id}, #{user_two.id}, #{user_three.id})")

      expect(query).to include(groups_user_one, groups_user_two, groups_user_three)
    end
  end
end
