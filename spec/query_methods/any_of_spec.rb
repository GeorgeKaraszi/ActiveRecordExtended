RSpec.describe "Active Record Either Methods" do
  let!(:one)       { Person.create!(personal_id: 1) }
  let!(:two)       { Person.create!(personal_id: 2) }
  let!(:three)     { Person.create!(personal_id: 3) }

  describe "where.any_of/1" do
    it "Should return queries that match any of the outlined queries" do
      query = Person.where.any_of({ personal_id: 1 }, { personal_id: 2})
      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    it "Should accept where query predicates" do
      personal_one = Person.where(personal_id: 1)
      personal_two = Person.where(personal_id: 2)
      query = Person.where.any_of(personal_one, personal_two)

      expect(query).to include(one, two)
      expect(query).to_not include(three)
    end

    it "Works with bound attributes" do
      personal_one = Person.where("personal_id >= 1").limit(2)
      query = Person.where.any_of(personal_one)

      expect(query).to include(one)
      expect(query).to_not include(two, three)
    end

    it "Should accept query strings" do
      personal_one = Person.where(personal_id: 1)

      query = Person.where.any_of(personal_one, "personal_id > 2")
      expect(query).to include(one, three)
      expect(query).to_not include(two)

      query = Person.where.any_of(["personal_id >= ?", 2])
      expect(query).to include(two, three)
      expect(query).to_not include(one)
    end

    it "Should accept joined where queries" do
      tag_one   = Tag.create!(person_id: one.id)
      tag_two   = Tag.create!(person_id: two.id)
      tag_three = Tag.create!(person_id: three.id)

      query = Tag.joins(:person).where.any_of(
          { people: { personal_id: 1 } },
          { people: { personal_id: 3 } }
      )

      expect(query).to include(tag_one, tag_three)
      expect(query).to_not include(tag_two)
    end
  end
end
