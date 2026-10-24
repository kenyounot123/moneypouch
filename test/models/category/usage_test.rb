require "test_helper"

class Category::UsageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @usage = Category::Usage.new(@user, Period.new("month", today: Date.new(2026, 10, 20)))
  end

  test "totals what a spending category spent and an income category received this period" do
    @user.transactions.create!(name: "Refund", amount_in_cents: 150, occurred_on: "2026-10-04", category: categories(:food))
    @user.transactions.create!(name: "Last month", amount_in_cents: -2000, occurred_on: "2026-09-30", category: categories(:food))

    assert_equal 400, @usage.total(categories(:food))
    assert_equal 200_000, @usage.total(categories(:income))
  end

  test "leaves excluded and deleted transactions out of the total but counts every kept one" do
    @user.transactions.create!(name: "Lunch", amount_in_cents: -1000, occurred_on: "2026-10-05", category: categories(:food)).exclude
    @user.transactions.create!(name: "Dinner", amount_in_cents: -3000, occurred_on: "2026-10-06", category: categories(:food)).discard

    assert_equal 550, @usage.total(categories(:food))
    assert_equal 2, @usage.transactions_count(categories(:food))
  end

  test "counts a category's rules and reads zero for an unused category" do
    @user.rules.create!(name_key: "tea", name: "Tea", category: categories(:food))
    lonely = @user.categories.create!(name: "Lonely")

    assert_equal 1, @usage.rules_count(categories(:food))
    assert_equal [ 0, 0, 0 ], [ @usage.total(lonely), @usage.transactions_count(lonely), @usage.rules_count(lonely) ]
  end
end
