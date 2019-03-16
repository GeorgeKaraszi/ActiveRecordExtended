# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Person < ApplicationRecord
  has_many :hm_tags, class_name: "Tag"
  has_one :profile_l, class_name: "ProfileL"
  has_one :profile_r, class_name: "ProfileR"
  # attributes
  # t.string   "tags",         array: true
  # t.integer  "number",       default: 0
  # t.integer  "personal_id"
  # t.hstore   "data"
  # t.jsonb    "jsonb_data"
  # t.inet     "ip"
  # t.cidr     "subnet"
  #
end

class Tag < ApplicationRecord
  belongs_to :person
  # attributes: tag_number
end

class ProfileL < ApplicationRecord
  belongs_to :person
  has_one :version, as: :versionable, class_name: "VersionControl"
  # attributes
  # t.integer :likes
  #
end

class ProfileR < ApplicationRecord
  belongs_to :person
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
