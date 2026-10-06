require "test_helper"

class SpendingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @transport = @user.categories.create!(name: "Transport")
  end

  test "sums only kept outflows in the period" do
    spend(-1_200, "2026-10-03", @transport)
    spend(-900, "2026-09-30")
    spend(-5_000, "2026-10-04").discard

    spending = Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5)))

    assert_equal 1_750, spending.total
  end

  test "ranks categories by amount and keeps uncategorized rows" do
    spend(-1_200, "2026-10-03", @transport)
    spend(-300, "2026-10-02")

    spending = Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5)))

    assert_equal [ [ "Transport", 1_200 ], [ "Food", 550 ], [ nil, 300 ] ],
      spending.categories.map { |category, cents| [ category&.name, cents ] }
  end

  test "gives each past day a total and each future day nil" do
    spend(-1_200, "2026-10-06", @transport)

    columns = Spending.new(@user.transactions, Period.new("week", today: Date.new(2026, 10, 7))).columns

    assert_equal [ 0, 1_200, 0, nil, nil, nil, nil ], columns.values
    assert_equal Date.new(2026, 10, 5), columns.keys.first
  end

  test "shows spending already entered for a future day" do
    spend(-210_000, "2026-10-31")

    spending = Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5)))

    assert_equal 210_000, spending.columns[Date.new(2026, 10, 31)]
    assert_equal 210_550, spending.total
    assert_equal 550, spending.elapsed_total
  end

  test "folds a year into month columns" do
    spend(-1_000, "2026-03-02")
    spend(-500, "2026-03-30")

    columns = Spending.new(@user.transactions, Period.new("year", today: Date.new(2026, 10, 5))).columns

    assert_equal 1_500, columns[Date.new(2026, 3, 1)]
    assert_equal 550, columns[Date.new(2026, 10, 1)]
    assert_nil columns[Date.new(2026, 11, 1)]
  end

  test "totals the same elapsed days of the previous period" do
    spend(-700, "2026-09-01")
    spend(-400, "2026-09-05")
    spend(-9_000, "2026-09-06")

    spending = Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5)))

    assert_equal 1_100, spending.previous_total
  end

  test "names the largest transaction in the busiest column" do
    spend(-1_200, "2026-10-03", @transport, name: "Uber")
    spend(-1_500, "2026-10-03", @transport, name: "Lyft")
    spend(-2_000, "2026-10-04", name: "Dinner")

    assert_equal "Lyft", Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5))).peak.name
  end

  test "names the largest transaction in the busiest month of a year" do
    spend(-80_000, "2026-03-02", name: "Laptop")
    spend(-30_000, "2026-03-20", name: "Phone")
    spend(-90_000, "2026-05-01", name: "Rent")

    assert_equal "Laptop", Spending.new(@user.transactions, Period.new("year", today: Date.new(2026, 10, 5))).peak.name
  end

  test "has no peak and zero totals without spending" do
    @user.transactions.each(&:discard)

    spending = Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5)))

    assert_nil spending.peak
    assert_equal [ 0, 0, [] ], [ spending.total, spending.previous_total, spending.categories ]
  end

  test "never counts another user's spending" do
    users(:two).transactions.create!(name: "Theirs", amount_in_cents: -9_999, occurred_on: "2026-10-02")

    assert_equal 550, Spending.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 5))).total
  end

  private
    def spend(cents, occurred_on, category = nil, name: "Thing")
      @user.transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
