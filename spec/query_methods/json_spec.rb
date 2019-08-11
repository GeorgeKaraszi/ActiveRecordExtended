# frozen_string_literal: true

RSpec.describe "Active Record JSON methods" do
  let!(:user_one) { User.create! }
  let!(:user_two) { User.create! }

  describe ".select_row_to_json" do
    let!(:tag_one)    { Tag.create!(user: user_one, tag_number: 2) }
    let!(:tag_two)    { Tag.create!(user: user_two, tag_number: 5) }
    let(:sub_query)   { Tag.select(:tag_number).where("tags.user_id = users.id") }

    it "should nest a json object in the query results" do
      query = User.select(:id).select_row_to_json(sub_query, as: :results).where(id: user_one.id)
      expect(query.size).to eq(1)
      expect(query.take.results).to be_a(Hash).and(match("tag_number" => 2))
    end

    # ugh wording here sucks, brain is fried.
    it "accepts a block for appending additional scopes to the middle-top level" do
      query = User.select(:id).select_row_to_json(sub_query, key: :tag_row, as: :results) do |scope|
        scope.where("tag_row.tag_number = 5")
      end

      expect(query.size).to eq(2)
      query.each do |result|
        if result.id == user_one.id
          expect(result.results).to be_blank
        else
          expect(result.results).to be_present.and(match("tag_number" => 5))
        end
      end
    end

    it "accepts a scope-block without arguments" do
      query = User.select(:id).select_row_to_json(sub_query, key: :tag_row, as: :results) do
        where("tag_row.tag_number = 5")
      end

      expect(query.size).to eq(2)
      query.each do |result|
        if result.id == user_one.id
          expect(result.results).to be_blank
        else
          expect(result.results).to be_present.and(match("tag_number" => 5))
        end
      end
    end

    it "allows for casting results in an aggregate-able Array function" do
      query = User.select(:id).select_row_to_json(sub_query, key: :tag_row, as: :results, cast_as_array: true)
      expect(query.take.results).to be_a(Array).and(be_present)
      expect(query.take.results.first).to be_a(Hash)
    end

    it "raises an error if a from clause key is missing" do
      expect do
        User.select(:id).select_row_to_json(key: :tag_row, as: :results)
      end.to raise_error(ArgumentError)
    end
  end

  describe ".json_build_object" do
    let(:sub_query) do
      User.select_row_to_json(from: User.select(:id), cast_as_array: true, as: :ids).where(id: user_one.id)
    end

    it "defaults the column alias if one is not provided" do
      query = User.json_build_object(:personal, sub_query)
      expect(query.size).to eq(1)
      expect(query.take.results).to match(
        "personal" => match("ids" => match_array([{ "id" => user_one.id }, { "id" => user_two.id }])),
      )
    end

    it "allows for re-aliasing the default 'results' column" do
      query = User.json_build_object(:personal, sub_query, as: :cool_dudes)
      expect(query.take).to respond_to(:cool_dudes)
    end
  end

  describe ".jsonb_build_object" do
    let(:sub_query) { User.select(:id, :number).where(id: user_one.id) }

    it "defaults the column alias if one is not provided" do
      query = User.jsonb_build_object(:personal, sub_query)
      expect(query.size).to eq(1)
      expect(query.take.results).to be_a(Hash).and(be_present)
      expect(query.take.results).to match("personal" => match("id" => user_one.id, "number" => user_one.number))
    end

    it "allows for re-aliasing the default 'results' column" do
      query = User.jsonb_build_object(:personal, sub_query, as: :cool_dudes)
      expect(query.take).to respond_to(:cool_dudes)
    end

    it "allows for custom value statement" do
      query = User.jsonb_build_object(
        :personal,
        sub_query.where.not(id: user_one),
        value: "COALESCE(array_agg(\"personal\"), '{}')",
        as:    :cool_dudes,
      )

      expect(query.take.cool_dudes["personal"]).to be_a(Array).and(be_empty)
    end

    it "will raise a warning if the value doesn't include a double quoted input" do
      expect do
        User.jsonb_build_object(
          :personal,
          sub_query.where.not(id: user_one),
          value: "COALESCE(array_agg(personal), '{}')",
          as:    :cool_dudes,
        )
      end.to output.to_stderr
    end
  end

  describe "Json literal builds" do
    let(:original_hash)      { { p: 1, b: "three", x: 3.14 } }
    let(:hash_as_array_objs) { original_hash.to_a.flatten }

    shared_examples_for "literal builds" do
      let(:method) { raise "You are expected to over ride this!" }

      it "will accept a hash arguments that will return itself" do
        query = User.send(method.to_sym, original_hash)
        expect(query.take.results).to be_a(Hash).and(be_present)
        expect(query.take.results).to match(original_hash.stringify_keys)
      end

      it "will accept a standard array of key values" do
        query = User.send(method.to_sym, hash_as_array_objs)
        expect(query.take.results).to be_a(Hash).and(be_present)
        expect(query.take.results).to match(original_hash.stringify_keys)
      end

      it "will accept a splatted array of key-values" do
        query = User.send(method.to_sym, *hash_as_array_objs)
        expect(query.take.results).to be_a(Hash).and(be_present)
        expect(query.take.results).to match(original_hash.stringify_keys)
      end
    end

    describe ".json_build_literal" do
      it_behaves_like "literal builds" do
        let!(:method) { :json_build_literal }
      end
    end

    describe ".jsonb_build_literal" do
      it_behaves_like "literal builds" do
        let!(:method) { :jsonb_build_literal }
      end
    end
  end
end
