# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record WITH CTE tables" do
  let(:with_personal_query) { /WITH.+personal_id_one.+AS \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\)/ }

  it "contains WITH statement that creates the CTE table" do
    query = User.with(personal_id_one: User.where(personal_id: 1))
                .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                .to_sql
    expect(query).to match_regex(with_personal_query)
  end

  it "maintains the CTE table when merging" do
    query = User.all
                .merge(User.with(personal_id_one: User.where(personal_id: 1)))
                .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                .to_sql

    expect(query).to match_regex(with_personal_query)
  end

  it "pipes Children CTE's into the Parent relation" do
    personal_id_one_query = User.where(personal_id: 1)
    personal_id_two_query = User.where(personal_id: 2)

    sub_query       = personal_id_two_query.with(personal_id_one: personal_id_one_query)
    query           = User.all.with(personal_id_two: sub_query)
    expected_order  = User.with(
      personal_id_one: personal_id_one_query,
      personal_id_two: personal_id_two_query
    )

    expect(query.to_sql).to eq(expected_order.to_sql)
  end

  context "when multiple CTE's" do
    let(:chained_with) do
      User.with(personal_id_one: User.where(personal_id: 1))
          .with(personal_id_two: User.where(personal_id: 2))
          .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
          .joins("JOIN personal_id_two ON personal_id_two.id = users.id")
          .to_sql
    end

    let(:with_arguments) do
      User.with(personal_id_one: User.where(personal_id: 1), personal_id_two: User.where(personal_id: 2))
          .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
          .joins("JOIN personal_id_two ON personal_id_two.id = users.id")
          .to_sql
    end

    it "only contains a single WITH statement" do
      expect(with_arguments.scan("WITH").count).to eq(1)
      expect(with_arguments.scan("AS").count).to eq(2)
    end

    it "only contains a single WITH statement when chaining" do
      expect(chained_with.scan("WITH").count).to eq(1)
      expect(chained_with.scan("AS").count).to eq(2)
    end
  end

  context "when using recursive methods" do
    let(:with_recursive_personal_query) do
      /WITH.+RECURSIVE.+personal_id_one.+AS \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\)/
    end

    it "generates an expression with recursive method chain" do
      query = User.with
                  .recursive(personal_id_one: User.where(personal_id: 1))
                  .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                  .to_sql

      expect(query).to match_regex(with_recursive_personal_query)
    end

    it "generates an expression with recursive opts" do
      query = User.with(:recursive, personal_id_one: User.where(personal_id: 1))
                  .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                  .to_sql

      expect(query).to match_regex(with_recursive_personal_query)
    end

    it "maintains the CTE table when merging" do
      sub_query = User.with.recursive(personal_id_one: User.where(personal_id: 1))
      query     = User.merge(sub_query)
                      .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                      .to_sql

      expect(query).to match_regex(with_recursive_personal_query)
    end
  end

  context "when chaining the materialized method" do
    let(:with_materialized_personal_query) do
      /WITH.+personal_id_one.+AS MATERIALIZED \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\)/
    end

    let(:with_materialized) do
      User.with
          .materialized(personal_id_one: User.where(personal_id: 1))
          .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
          .to_sql
    end

    it "generates an expression with materialized" do
      query = User.with
                  .materialized(personal_id_one: User.where(personal_id: 1))
                  .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                  .to_sql

      expect(query).to match_regex(with_materialized_personal_query)
    end

    it "maintains the CTE table when merging" do
      sub_query = User.with
                      .materialized(materialized_personal_id_one: User.where(personal_id: 1))
                      .with(personal_id_one: User.where(personal_id: 1))
      query = User.merge(sub_query)
                  .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                  .to_sql

      expected_order = /WITH.+materialized_personal_id_one.+AS MATERIALIZED \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\),.+personal_id_one.+AS \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\)/

      expect(query).to match_regex(expected_order)
    end

    it "raises an error if CTE is already not_materialized for that key" do
      materialized_query = User.with.materialized(personal_id_one: User.where(personal_id: 1))

      expect do
        materialized_query
          .with
          .not_materialized(personal_id_one: User.where(personal_id: 1))
          .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
      end.to raise_error(ArgumentError, "CTE already set as materialized")
    end

    it "pipes Children CTE's into the Parent relation" do
      personal_id_one_query = User.where(personal_id: 1)
      personal_id_two_query = User.where(personal_id: 2)

      sub_query       = personal_id_two_query.with.materialized(personal_id_one: personal_id_one_query)
      query           = User.all.with(personal_id_two: sub_query)

      expected_order = /WITH.+personal_id_one.+AS MATERIALIZED \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\),.+personal_id_two.+AS \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 2\)/

      expect(query.to_sql).to match_regex(expected_order)
    end
  end

  context "when chaining the not_materialized method" do
    let(:with_not_materialized_personal_query) do
      /WITH.+personal_id_one.+AS NOT MATERIALIZED \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\)/
    end

    let(:with_not_materialized) do
      User.with
          .not_materialized(personal_id_one: User.where(personal_id: 1))
          .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
          .to_sql
    end

    it "generates an expression with not_materialized" do
      query = User.with
                  .not_materialized(personal_id_one: User.where(personal_id: 1))
                  .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                  .to_sql

      expect(query).to match_regex(with_not_materialized_personal_query)
    end

    it "maintains the CTE table when merging" do
      sub_query = User.with
                      .not_materialized(not_materialized_personal_id_one: User.where(personal_id: 1))
                      .with(personal_id_one: User.where(personal_id: 1))
      query     = User.merge(sub_query)
                      .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
                      .to_sql

      expected_order = /WITH.+not_materialized_personal_id_one.+AS NOT MATERIALIZED \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\),.+personal_id_one.+AS \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\)/

      expect(query).to match_regex(expected_order)
    end

    it "raises an error if CTE is already materialized for that key" do
      materialized_query = User.with.not_materialized(personal_id_one: User.where(personal_id: 1))

      expect do
        materialized_query
          .with
          .materialized(personal_id_one: User.where(personal_id: 1))
          .joins("JOIN personal_id_one ON personal_id_one.id = users.id")
      end.to raise_error(ArgumentError, "CTE already set as not_materialized")
    end

    it "pipes Children CTE's into the Parent relation" do
      personal_id_one_query = User.where(personal_id: 1)
      personal_id_two_query = User.where(personal_id: 2)

      sub_query       = personal_id_two_query.with.not_materialized(personal_id_one: personal_id_one_query)
      query           = User.all.with(personal_id_two: sub_query)

      expected_order = /WITH.+personal_id_one.+AS NOT MATERIALIZED \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 1\),.+personal_id_two.+AS \(SELECT.+users.+FROM.+WHERE.+users.+personal_id.+ = 2\)/

      expect(query.to_sql).to match_regex(expected_order)
    end
  end
end
