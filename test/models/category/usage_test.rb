require "test_helper"

class Category::UsageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @today = Date.new(2026, 10, 20)
    @usage = usage_over(months: "1")
  end

  test "totals what a spending category spent and an income category took in over the span" do
    @user.transactions.create!(name: "Refund", amount_in_cents: 150, occurred_on: "2026-10-04", category: categories(:food))
    @user.transactions.create!(name: "Last month", amount_in_cents: -2000, occurred_on: "2026-09-30", category: categories(:food))

    assert_equal 400, @usage.total(categories(:food))
    assert_equal 150, @usage.refunded(categories(:food))
    assert_equal 200_000, @usage.total(categories(:income))
    assert_equal 2400, usage_over(months: "3").total(categories(:food))
  end

  test "leaves excluded and deleted transactions out of the total but counts every kept one" do
    @user.transactions.create!(name: "Lunch", amount_in_cents: -1000, occurred_on: "2026-10-05", category: categories(:food)).exclude
    @user.transactions.create!(name: "Dinner", amount_in_cents: -3000, occurred_on: "2026-10-06", category: categories(:food)).discard

    assert_equal 550, @usage.total(categories(:food))
    assert_equal 2, @usage.transactions_count(categories(:food))
  end

  test "a category with nothing in the span is inactive and knows its last transaction" do
    trip = @user.categories.create!(name: "Trip")
    @user.transactions.create!(name: "Flight", amount_in_cents: -40_000, occurred_on: "2026-07-07", category: trip)

    assert_not @usage.active?(trip)
    assert_equal Date.new(2026, 7, 7), @usage.last_on(trip)
    assert usage_over(months: "12").active?(trip)
  end

  test "an excluded transaction keeps a category active since its page lists it" do
    @user.transactions.create!(name: "Gift card", amount_in_cents: -2000, occurred_on: "2026-10-05", category: categories(:food)).exclude
    trip = @user.categories.create!(name: "Trip")
    @user.transactions.create!(name: "Hotel", amount_in_cents: -2000, occurred_on: "2026-10-05", category: trip).exclude

    assert @usage.active?(trip)
    assert_equal 0, @usage.total(trip)
  end

  test "totals each of the last 12 months and averages them" do
    @user.transactions.create!(name: "Tacos", amount_in_cents: -1150, occurred_on: "2026-07-12", category: categories(:food))
    @user.transactions.create!(name: "Old", amount_in_cents: -9000, occurred_on: "2025-10-31", category: categories(:food))

    months = usage_over(month: "2026-07").months(categories(:food))

    assert_equal 12, months.size
    assert_equal [ Date.new(2025, 11, 1), Date.new(2026, 10, 1) ], [ months.keys.first.first_day, months.keys.last.first_day ]
    assert_equal 1150, months[Period.month("2026-07", today: @today)]
    assert_equal 550, months.values.last
    assert_equal 141, @usage.monthly_average(categories(:food))
  end

  test "counts a category's rules and reads zero for an unused category" do
    @user.rules.create!(name_key: "tea", name: "Tea", category: categories(:food))
    lonely = @user.categories.create!(name: "Lonely")

    assert_equal 1, @usage.rules_count(categories(:food))
    assert_equal [ 0, 0, 0, nil ], [ @usage.total(lonely), @usage.transactions_count(lonely), @usage.rules_count(lonely), @usage.last_on(lonely) ]
  end

  private
    def usage_over(params)
      Category::Usage.new(@user, Category::Span.from(params, today: @today))
    end
end
