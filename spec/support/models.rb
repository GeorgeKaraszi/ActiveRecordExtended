
# frozen_string_literal: true

class Person < ActiveRecord::Base
  has_many :hm_tags, class_name: "Tag"
end

class Tag < ActiveRecord::Base
  belongs_to :person
end
