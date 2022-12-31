# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))

require "active_record_extended/version"

Gem::Specification.new do |spec|
  spec.name                  = "active_record_extended"
  spec.version               = ActiveRecordExtended::VERSION
  spec.authors               = ["George Protacio-Karaszi", "Dan McClain", "Olivier El Mekki"]
  spec.email                 = ["georgekaraszi@gmail.com", "git@danmcclain.net", "olivier@el-mekki.com"]

  spec.summary               = "Adds extended functionality to Activerecord Postgres implementation"
  spec.description           = "Adds extended functionality to Activerecord Postgres implementation"
  spec.homepage              = "https://github.com/georgekaraszi/ActiveRecordExtended"
  spec.license               = "MIT"

  spec.files                 = Dir["README.md", "lib/**/*"]
  spec.require_paths         = ["lib"]
  spec.required_ruby_version = ">= 2.7"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "activerecord", ">= 5.2", "< 7.1.0"
  spec.add_dependency "pg", "< 3.0"

  spec.add_development_dependency "bundler", ">= 2.2", "< 3.0"
  spec.add_development_dependency "database_cleaner", "~> 2.0"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.16"
end
