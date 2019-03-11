# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Union Methods" do
  let!(:person_one)     { Person.create! }
  let!(:person_two)     { Person.create! }
  let!(:person_three)   { Person.create! }
  let!(:person_one_pl)  { ProfileL.create!(person: person_one, likes: 100) }
  let!(:person_two_pl)  { ProfileL.create!(person: person_two, likes: 200) }

  shared_examples_for "standard set of errors" do
    let(:person_one_query)  { Person.select(:id).where(id: person_one.id) }
    let(:person_two_query)  { Person.select(:id, :tags).where(id: person_two.id) }
    let(:misaligned_cmd)    { raise("required to override this 'let' statement") }
    let(:lacking_union_cmd) { raise("required to override this 'let' statement") }

    it "should raise an error if the select statements do not align" do
      expect { misaligned_cmd.to_a }.to(
        raise_error(ActiveRecord::StatementInvalid, /each [[:alpha:]]+ query must have the same number of columns/),
      )
    end

    it "should raise an argument error if there are less then two union statements" do
      expect { lacking_union_cmd.to_a }.to(
        raise_error(ArgumentError, "You are required to provide 2 or more unions to join!"),
      )
    end
  end

  describe ".union" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { Person.union(person_one_query, person_two_query) }
      let!(:lacking_union_cmd) { Person.union(person_one_query) }
    end

    it "should return two users that match the where conditions" do
      query = Person.union(Person.where(id: person_one.id), Person.where(id: person_three.id))
      expect(query).to match_array([person_one, person_three])
    end

    it "should allow joins on union statements" do
      query = Person.union(Person.where(id: person_one.id), Person.joins(:profile_l).where.not(id: person_one.id))
      expect(query).to match_array([person_one, person_two])
    end

    it "should eliminate duplicate results" do
      expected_ids = Person.pluck(:id)
      query        = Person.union(Person.select(:id), Person.select(:id))
      expect(query.pluck(:id)).to have_attributes(size: expected_ids.size).and(match_array(expected_ids))
    end
  end

  describe ".union.all" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { Person.union.all(person_one_query, person_two_query) }
      let!(:lacking_union_cmd) { Person.union.all(person_one_query) }
    end

    it "should keep duplicate results from each union statement" do
      expected_ids = Person.pluck(:id) * 2
      query        = Person.union.all(Person.select(:id), Person.select(:id))
      expect(query.pluck(:id)).to have_attributes(size: expected_ids.size).and(match_array(expected_ids))
    end
  end

  describe ".union.except" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { Person.union.except(person_one_query, person_two_query) }
      let!(:lacking_union_cmd) { Person.union.except(person_one_query) }
    end

    it "should eliminate records that match a given except statement" do
      query = Person.union.except(Person.select(:id), Person.select(:id).where(id: person_one.id))
      expect(query).to match_array([person_two, person_three])
    end
  end

  describe "union.intersect" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { Person.union.intersect(person_one_query, person_two_query) }
      let!(:lacking_union_cmd) { Person.union.intersect(person_one_query) }
    end

    it "should find records with similar attributes" do
      ProfileL.create!(person: person_three, likes: 120)

      query =
        Person.union.intersect(
          Person.select(:id, "profile_ls.likes").joins(:profile_l).where(profile_ls: { likes: 100 }),
          Person.select(:id, "profile_ls.likes").joins(:profile_l).where("profile_ls.likes < 150"),
        )

      expect(query.pluck(:id)).to have_attributes(size: 1).and(eq([person_one_pl.id]))
      expect(query.first.likes).to eq(person_one_pl.likes)
    end
  end

  describe "union.as" do
    let(:query) do
      Person.select("happy_people.id")
            .union(Person.where(id: person_one.id), Person.where(id: person_three.id))
            .union.as(:happy_people)
    end

    it "should return two people" do
      expect(query.size).to eq(2)
    end

    it "should return two peoples id's" do
      expect(query.map(&:id)).to match_array([person_one.id, person_three.id])
    end

    it "should alias the tables being union'd but still allow for accessing table methods" do
      query.each do |happy_person|
        expect(happy_person).to respond_to(:profile_l)
      end
    end
  end

  describe "union.order" do
    it "should order the .union commands" do
      query = Person.union(Person.where(id: person_one.id), Person.where(id: person_three.id)).union.order(id: :desc)
      expect(query).to eq([person_three, person_one])
    end

    it "should order the .union.all commands" do
      query =
        Person.union.all(
          Person.where(id: person_one.id),
          Person.where(id: person_three.id),
        ).union.order(id: :desc)

      expect(query).to eq([person_three, person_one])
    end

    it "should order the union.except commands" do
      query = Person.union.except(Person.order(id: :asc), Person.where(id: person_one.id)).union.order(id: :desc)
      expect(query).to eq([person_three, person_two])
    end

    it "should order the .union.intersect commands" do
      query =
        Person.union.intersect(
          Person.where("id < ?", person_three.id),
          Person.where("id >= ?", person_one.id),
        ).union.order(id: :desc)

      expect(query).to eq([person_two, person_one])
    end
  end
end
