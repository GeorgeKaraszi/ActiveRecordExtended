# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Union SQL Queries" do
  let(:person)       { Person.where(id: 1) }
  let(:other_person) { Person.where("id = 2") }

  shared_examples_for "unions" do
    it { is_expected.to eq("( (#{person.to_sql}) #{described_union} (#{other_person.to_sql}) )") }
  end

  describe ".union" do
    let!(:described_union)     { "UNION" }
    subject(:described_method) { Person.union(person, other_person).to_union_sql }
    it_behaves_like "unions"
  end

  describe ".union.all" do
    let!(:described_union)     { "UNION ALL" }
    subject(:described_method) { Person.union.all(person, other_person).to_union_sql }
    it_behaves_like "unions"
  end

  describe ".union.except" do
    let!(:described_union)     { "EXCEPT" }
    subject(:described_method) { Person.union.except(person, other_person).to_union_sql }
    it_behaves_like "unions"
  end

  describe "union.intersect" do
    let!(:described_union)     { "INTERSECT" }
    subject(:described_method) { Person.union.intersect(person, other_person).to_union_sql }
    it_behaves_like "unions"
  end

  describe "union.as" do
    context "when a union.as has been called" do
      subject(:described_method) do
        Person.select("happy_people.id").union(person, other_person).union.as(:happy_people).to_sql
      end

      it "should alias the union from clause to 'happy_people'" do
        expect(described_method).to match_regex(/FROM \(+.+\) UNION \(.+\)+ happy_people$/)
        expect(described_method).to match_regex(/^SELECT happy_people\.id FROM.+happy_people$/)
      end
    end

    context "when user.as hasn't been called" do
      subject(:described_method) { Person.select(:id).union(person, other_person).to_sql }

      it "should retain the actual class calling table name as the union alias" do
        expect(described_method).to match_regex(/FROM \(+.+\) UNION \(.+\)+ people$/)
        expect(described_method).to match_regex(/^SELECT \"people\"\.\"id\" FROM.+people$/)
      end
    end
  end

  describe "union.order" do
    context "when rendering with .to_union_sql" do
      subject(:described_method) { Person.union(person, other_person).union.order(:id, name: :desc).to_union_sql }

      it "Should append an 'ORDER BY' to the end of the union statements" do
        expect(described_method).to match_regex(/^\(+.+\) UNION \(.+\) \) ORDER BY id, name DESC$/)
      end
    end

    context "when rendering with .to_sql" do
      subject(:described_method) { Person.union(person, other_person).union.order(:id, name: :desc).to_sql }

      it "Should append an 'ORDER BY' to the end of the union statements" do
        expect(described_method).to match_regex(/FROM \(+.+\) UNION \(.+\) \) ORDER BY id, name DESC\) people$/)
      end
    end

    context "when a there are multiple union statements" do
      let(:query_regex) { /(?<=\)\s(ORDER BY)) id/ }

      it "should only append an order by to the very end of a union statements" do
        query = Person.union.order(id: :asc, tags: :desc)
                      .union(person.order(id: :asc, tags: :desc))
                      .union(person.order(:id, :tags))
                      .union(other_person.order(id: :desc, tags: :desc))
                      .to_union_sql

        index = query.index(query_regex)
        expect(index).to be_truthy
        expect(query[index..-1]).to eq(" id ASC, tags DESC")
      end
    end
  end
end
