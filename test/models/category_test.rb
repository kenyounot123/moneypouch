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

  test "revise renames a category" do
    assert categories(:food).revise(name: "  Eating   out ")
    assert_equal "Eating out", categories(:food).reload.name
  end

  test "revise onto another category's name refuses and says to merge" do
    assert_not categories(:food).revise(name: "income")
    assert_equal [ "income is already a category. Merge into it instead." ], categories(:food).errors.full_messages
    assert_equal "Food", categories(:food).reload.name
  end

  test "revise can count a category as income" do
    assert_difference -> { users(:one).transactions.spent }, -550 do
      categories(:food).revise(income: true)
    end
  end

  test "merge_into moves transactions, deleted ones too, and rules, then drops the category" do
    user = users(:one)
    foods = user.categories.create!(name: "Foods")
    tacos = user.transactions.create!(name: "Tacos", amount_in_cents: -900, occurred_on: "2026-10-02", category: foods)
    gone = user.transactions.create!(name: "Ramen", amount_in_cents: -1400, occurred_on: "2026-10-03", category: foods)
    gone.discard
    rule = user.rules.create!(name_key: "tacos", name: "Tacos", category: foods)

    foods.merge_into(categories(:food))

    assert_not Category.exists?(foods.id)
    assert_equal [ categories(:food) ] * 3, [ tacos, gone, rule ].map { it.reload.category }
  end

  test "merge_into refuses the category itself and another user's category" do
    assert_raises(ArgumentError) { categories(:food).merge_into(categories(:food)) }
    assert_raises(ArgumentError) { categories(:food).merge_into(categories(:income_two)) }
    assert Category.exists?(categories(:food).id)
  end

  test "remove leaves its transactions uncategorized and forgets its rules" do
    user = users(:one)
    user.rules.create!(name_key: "blue bottle", name: "Blue Bottle", category: categories(:food))

    categories(:food).remove

    assert_nil transactions(:coffee).reload.category
    assert_equal 0, user.rules.count
  end
end
