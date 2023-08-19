# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class User < ApplicationRecord
  has_many :groups_users, class_name: "GroupsUser"
  has_many :groups, through: :groups_users, dependent: :destroy
  has_many :hm_tags, class_name: "Tag"
  has_one :profile_l, class_name: "ProfileL"
  has_one :profile_r, class_name: "ProfileR"

  # attributes
  # t.string   "tags",         array: true
  # t.integer  "number",       default: 0
  # t.string   "name"
  # t.integer  "personal_id"
  # t.hstore   "data"
  # t.jsonb    "jsonb_data"
  # t.inet     "ip"
  # t.cidr     "subnet"
  #
end

class StiRecord < ApplicationRecord
  # t.string "type"
end

class AdminSti < StiRecord; end

module Namespaced
  def self.table_name_prefix
    "namespaced_"
  end

  class Record < ApplicationRecord
    # attributes
    # t.inet :ip
    # t.cidr :subnet
    #
  end
end

class Tag < ApplicationRecord
  belongs_to :user
  # attributes: tag_number
end

class ProfileL < ApplicationRecord
  belongs_to :user
  has_one :version, as: :versionable, class_name: "VersionControl"
  # attributes
  # t.integer :likes
  #
end

class ProfileR < ApplicationRecord
  belongs_to :user
  has_one :version, as: :versionable, class_name: "VersionControl"
  # attributes
  # t.integer :dislikes
  #
end

class VersionControl < ApplicationRecord
  belongs_to :versionable, polymorphic: true, optional: false
  # attributes
  # t.jsonb :source, default: {}, null: false
  #
end

class Group < ApplicationRecord
  has_many :groups_users, class_name: "GroupsUser"
  has_many :users, through: :groups_users, dependent: :destroy
end

class GroupsUser < ApplicationRecord
  belongs_to :user
  belongs_to :group
  scope :for_users, ->(user_ids) { where(user_id: user_ids).combine_with_in }
  scope :for_group, ->(group_ids) { where(group_id: group_ids).combine_with_in }
end
