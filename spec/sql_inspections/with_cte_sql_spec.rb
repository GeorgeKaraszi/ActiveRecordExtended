# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record WITH CTE tables" do
  let(:with_personal_query) { /WITH.+personal_id_one.+AS \(SELECT.+people.+FROM.+WHERE.+people.+personal_id.+ = 1\)/ }

  it "should contain WITH statement that creates the CTE table" do
    query = Person.with(personal_id_one: Person.where(personal_id: 1))
                  .joins("JOIN personal_id_one ON personal_id_one.id = people.id")
                  .to_sql
    expect(query).to match_regex(with_personal_query)
  end

  it "will maintain the CTE table when merging" do
    query = Person.merge(Person.with(personal_id_one: Person.where(personal_id: 1)))
                  .joins("JOIN personal_id_one ON personal_id_one.id = people.id")
                  .to_sql

    expect(query).to match_regex(with_personal_query)
  end

  context "when multiple CTE's" do
    let(:chained_with) do
      Person.with(personal_id_one: Person.where(personal_id: 1))
            .with(personal_id_two: Person.where(personal_id: 2))
            .joins("JOIN personal_id_one ON personal_id_one.id = people.id")
            .joins("JOIN personal_id_two ON personal_id_two.id = people.id")
            .to_sql
    end

    let(:with_arguments) do
      Person.with(personal_id_one: Person.where(personal_id: 1), personal_id_two: Person.where(personal_id: 2))
            .joins("JOIN personal_id_one ON personal_id_one.id = people.id")
            .joins("JOIN personal_id_two ON personal_id_two.id = people.id")
            .to_sql
    end
    it "Should only contain a single WITH statement" do
      expect(with_arguments.scan(/WITH/).count).to eq(1)
      expect(with_arguments.scan(/AS/).count).to eq(2)
    end

    it "Should only contain a single WITH statement when chaining" do
      expect(chained_with.scan(/WITH/).count).to eq(1)
      expect(chained_with.scan(/AS/).count).to eq(2)
    end
  end

  context "when chaining the recursive method" do
    let(:with_recursive_personal_query) do
      /WITH.+RECURSIVE.+personal_id_one.+AS \(SELECT.+people.+FROM.+WHERE.+people.+personal_id.+ = 1\)/
    end

    let(:with_recursive) do
      Person.with
            .recursive(personal_id_one: Person.where(personal_id: 1))
            .joins("JOIN personal_id_one ON personal_id_one.id = people.id")
            .to_sql
    end

    it "generates an expression with recursive" do
      expect(with_recursive).to match_regex(with_recursive_personal_query)
    end
  end
end
