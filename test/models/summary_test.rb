require "test_helper"

class SummaryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.transactions.destroy_all
    @summary = Summary.new(@user.transactions, today: Date.new(2026, 10, 15))
  end

  test "lists the current month and the five before it, oldest first" do
    assert_equal %w[ 2026-05 2026-06 2026-07 2026-08 2026-09 2026-10 ], @summary.months.map(&:to_param)
  end

  test "crosses a year boundary" do
    summary = Summary.new(@user.transactions, today: Date.new(2026, 2, 3))

    assert_equal %w[ 2025-09 2025-10 2025-11 2025-12 2026-01 2026-02 ], summary.months.map(&:to_param)
  end

  test "totals income and spent per month in cents, and a month can end below zero" do
    add 789_000, "2026-09-01", "Acme payroll"
    add(-397_712, "2026-09-30", "Rent", categories(:food))
    add 100_000, "2026-07-31", "Acme payroll"
    add(-131_000, "2026-07-01", "Rent")
    add(-500, "2026-10-14", "Coffee")

    totals = @summary.totals.map { |total| [ total.month.to_param, total.income, total.spent, total.net ] }

    assert_equal [
      [ "2026-05", 0, 0, 0 ],
      [ "2026-06", 0, 0, 0 ],
      [ "2026-07", 100_000, 131_000, -31_000 ],
      [ "2026-08", 0, 0, 0 ],
      [ "2026-09", 789_000, 397_712, 391_288 ],
      [ "2026-10", 0, 500, -500 ]
    ], totals
  end

  test "leaves transfers, discarded rows, older months, and other users out" do
    add 50_000, "2026-09-02", "Savings in"
    @user.transactions.last.categorize(Transaction::Categorization.transfer)
    add 70_000, "2026-09-03", "Gift"
    @user.transactions.last.discard
    add 9_999, "2026-04-30", "Too old"
    users(:two).transactions.create!(name: "Theirs", amount_in_cents: 8_888, occurred_on: "2026-09-04")

    assert_equal [ 0, 0 ], @summary.totals[4].then { |total| [ total.income, total.spent ] }
    assert_equal [], @summary.sources(Month.new("2026-09", today: Date.new(2026, 10, 15)))
  end

  test "a refund with a category nets against spending instead of counting as income" do
    add(-10_000, "2026-09-02", "Shoes", categories(:food))
    add 4_000, "2026-09-05", "Shoes back", categories(:food)

    total = @summary.totals[4]

    assert_equal [ 0, 6_000 ], [ total.income, total.spent ]
  end

  test "ranks a month's income sources largest first and sums rows with the same name" do
    add 500_000, "2026-09-01", "Acme payroll"
    add 250_000, "2026-09-15", "Acme bonus"
    add 15_000, "2026-09-10", "Interest"
    add 15_000, "2026-09-20", "Interest"
    add 99_000, "2026-08-31", "Last month"

    sources = @summary.sources(Month.new("2026-09", today: Date.new(2026, 10, 15)))

    assert_equal [ [ "Acme payroll", 500_000 ], [ "Acme bonus", 250_000 ], [ "Interest", 30_000 ] ], sources
  end

  test "ranks a month's spending by category" do
    add(-1_200, "2026-09-03", "Bus", categories(:food))
    add(-300, "2026-09-04", "Gum")
    add(-9_000, "2026-10-01", "Other month", categories(:food))

    categories = @summary.categories(Month.new("2026-09", today: Date.new(2026, 10, 15)))

    assert_equal [ [ "Food", 1_200 ], [ nil, 300 ] ], categories.map { |category, cents| [ category&.name, cents ] }
  end

  private
    def add(cents, occurred_on, name, category = nil)
      @user.transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
