# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Array value SQL queries" do
  context "when the column is an array" do
    it "compares the whole array" do
      expect(User.where(tags: ["a", "b"]).to_sql).to include(%("users"."tags" = '{a,b}'))
    end
  end

  context "when the array column belongs to a joined table" do
    it "compares the whole array" do
      query = Tag.joins(:user).where(users: { tag_ids: [1, 2] }).to_sql

      expect(query).to include(%("users"."tag_ids" = '{1,2}'))
    end
  end

  context "when the column is not an array" do
    it "matches any of the values" do
      expect(User.where(name: ["a", "b"]).to_sql).to include(%("users"."name" IN ('a', 'b')))
    end
  end

  context "when the model connects to another database than ActiveRecord::Base" do
    before do
      stub_const("SecondaryRecord", Class.new(ActiveRecord::Base) { self.abstract_class = true })
      SecondaryRecord.establish_connection(ENV.fetch("DATABASE_URL"))
      stub_const("SecondaryUser", Class.new(SecondaryRecord) { self.table_name = "users" })
      ActiveRecord::Base.remove_connection
    end

    after do
      SecondaryRecord.remove_connection
      ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URL"))
    end

    it "builds the query without a connection on ActiveRecord::Base" do
      expect(SecondaryUser.where(name: ["a", "b"]).to_sql).to include(%("users"."name" IN ('a', 'b')))
    end
  end
end
