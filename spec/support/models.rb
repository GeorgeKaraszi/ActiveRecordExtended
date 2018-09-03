# frozen_string_literal: true

class Person < ActiveRecord::Base
  has_many :hm_tags, class_name: "Tag"
  has_one :profile_l, class_name: "ProfileL"
  has_one :profile_r, class_name: "ProfileR"
end

class Tag < ActiveRecord::Base
  belongs_to :person
end

class ProfileL < ActiveRecord::Base
  belongs_to :person
end

class ProfileR < ActiveRecord::Base
  belongs_to :person
end
