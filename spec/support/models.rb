# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Person < ApplicationRecord
  has_many :hm_tags, class_name: "Tag"
  has_one :profile_l, class_name: "ProfileL"
  has_one :profile_r, class_name: "ProfileR"
end

class Tag < ApplicationRecord
  belongs_to :person
end

class ProfileL < ApplicationRecord
  belongs_to :person
  has_one :version, as: :versionable, class_name: "VersionControl"
end

class ProfileR < ApplicationRecord
  belongs_to :person
  has_one :version, as: :versionable, class_name: "VersionControl"
end

class VersionControl < ApplicationRecord
  belongs_to :versionable, polymorphic: true, optional: false
end
