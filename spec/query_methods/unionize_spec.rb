# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Active Record Union Methods" do
  let!(:user_one)     { User.create!(number: 8) }
  let!(:user_two)     { User.create!(number: 10) }
  let!(:user_three)   { User.create!(number: 1) }
  let!(:user_one_pl)  { ProfileL.create!(user: user_one, likes: 100) }
  let!(:user_two_pl)  { ProfileL.create!(user: user_two, likes: 200) }

  shared_examples_for "standard set of errors" do
    let(:user_one_query)  { User.select(:id).where(id: user_one.id) }
    let(:user_two_query)  { User.select(:id, :tags).where(id: user_two.id) }
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
      let!(:misaligned_cmd)    { User.union(user_one_query, user_two_query) }
      let!(:lacking_union_cmd) { User.union(user_one_query) }
    end

    it "should return two users that match the where conditions" do
      query = User.union(User.where(id: user_one.id), User.where(id: user_three.id))
      expect(query).to match_array([user_one, user_three])
    end

    it "should allow joins on union statements" do
      query = User.union(User.where(id: user_one.id), User.joins(:profile_l).where.not(id: user_one.id))
      expect(query).to match_array([user_one, user_two])
    end

    it "should eliminate duplicate results" do
      expected_ids = User.pluck(:id)
      query        = User.union(User.select(:id), User.select(:id))
      expect(query.pluck(:id)).to have_attributes(size: expected_ids.size).and(match_array(expected_ids))
    end
  end

  describe ".union.all" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { User.union.all(user_one_query, user_two_query) }
      let!(:lacking_union_cmd) { User.union.all(user_one_query) }
    end

    it "should keep duplicate results from each union statement" do
      expected_ids = User.pluck(:id) * 2
      query        = User.union.all(User.select(:id), User.select(:id))
      expect(query.pluck(:id)).to have_attributes(size: expected_ids.size).and(match_array(expected_ids))
    end
  end

  describe ".union.except" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { User.union.except(user_one_query, user_two_query) }
      let!(:lacking_union_cmd) { User.union.except(user_one_query) }
    end

    it "should eliminate records that match a given except statement" do
      query = User.union.except(User.select(:id), User.select(:id).where(id: user_one.id))
      expect(query).to match_array([user_two, user_three])
    end
  end

  describe "union.intersect" do
    it_behaves_like "standard set of errors" do
      let!(:misaligned_cmd)    { User.union.intersect(user_one_query, user_two_query) }
      let!(:lacking_union_cmd) { User.union.intersect(user_one_query) }
    end

    it "should find records with similar attributes" do
      ProfileL.create!(user: user_three, likes: 120)

      query =
        User.union.intersect(
          User.select(:id, "profile_ls.likes").joins(:profile_l).where(profile_ls: { likes: 100 }),
          User.select(:id, "profile_ls.likes").joins(:profile_l).where("profile_ls.likes < 150"),
        )

      expect(query.pluck(:id)).to have_attributes(size: 1).and(eq([user_one_pl.id]))
      expect(query.first.likes).to eq(user_one_pl.likes)
    end
  end

  describe "union.as" do
    let(:query) do
      User
        .select("happy_users.id")
        .union(User.where(id: user_one.id), User.where(id: user_three.id))
        .union_as(:happy_users)
    end

    it "should return two users" do
      expect(query.size).to eq(2)
    end

    it "should return two userss id's" do
      expect(query.map(&:id)).to match_array([user_one.id, user_three.id])
    end

    it "should alias the tables being union'd but still allow for accessing table methods" do
      query.each do |happy_person|
        expect(happy_person).to respond_to(:profile_l)
      end
    end
  end

  describe "union.order_union" do
    it "should order the .union commands" do
      query = User.union(User.where(id: user_one.id), User.where(id: user_three.id)).order_union(id: :desc)
      expect(query).to eq([user_three, user_one])
    end

    it "should order the .union.all commands" do
      query =
        User.union.all(
          User.where(id: user_one.id),
          User.where(id: user_three.id),
        ).order_union(id: :desc)

      expect(query).to eq([user_three, user_one])
    end

    it "should order the union.except commands" do
      query = User.union.except(User.order(id: :asc), User.where(id: user_one.id)).order_union(id: :desc)
      expect(query).to eq([user_three, user_two])
    end

    it "should order the .union.intersect commands" do
      query =
        User.union.intersect(
          User.where("id < ?", user_three.id),
          User.where("id >= ?", user_one.id),
        ).order_union(id: :desc)

      expect(query).to eq([user_two, user_one])
    end
  end

  describe "union.reorder_union" do
    it "should replace the ordering with the new parameters" do
      user_a           = User.create!(number: 1)
      user_b           = User.create!(number: 10)
      initial_ordering = [user_b, user_a]
      query            = User.union(User.where(id: user_a.id), User.where(id: user_b.id)).order_union(id: :desc)

      expect(query).to eq(initial_ordering)
      expect(query.reorder_union(number: :asc)).to eq(initial_ordering.reverse)
    end
  end
end
