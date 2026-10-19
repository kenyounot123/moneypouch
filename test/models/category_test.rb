require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "one user cannot hold Food and food" do
    assert_raises(ActiveRecord::RecordNotUnique) { users(:one).categories.create!(name: "food") }
  end

  test "two users can each hold Food" do
    assert_equal "Food", users(:two).categories.create!(name: "Food").name
  end

  test "named matches ignoring ASCII case" do
    assert_equal [ "Food" ], users(:one).categories.named("FOOD").pluck(:name)
  end

  test "unused leaves out a category any transaction or rule points at, even a deleted transaction" do
    user = users(:one)
    user.categories.create!(name: "Lonely")
    user.rules.create!(name_key: "tea", name: "Tea", category: user.categories.create!(name: "Ruled"))
    user.transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02", category: user.categories.create!(name: "Was used")).discard

    assert_equal [ "Lonely" ], user.categories.unused.pluck(:name)
  end
end
