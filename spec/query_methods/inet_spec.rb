# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Inet Query Methods" do
  describe "Deprecation Notices" do
    %i[contained_within contained_within_or_equals contains_or_equals].each do |method|
      it "Should display a deprecation warning for #{method}" do
        new_method  = "inet_#{method}".to_sym
        warning_msg = "##{method} will soon be deprecated for version 1.0 release. Please use ##{new_method} instead."
        expect_any_instance_of(ActiveRecordExtended::QueryMethods::Inet).to receive(new_method)
        expect { Person.where.send(method, nil) }.to output(Regexp.new(warning_msg)).to_stderr
      end
    end
  end
end
