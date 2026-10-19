require "test_helper"

class SummaryTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.transactions.destroy_all
    @today = Date.new(2026, 10, 15)
    @summary = Summary.new(@user.transactions, Period.new("month", today: Date.new(2026, 10, 15)))
  end

  test "lists the current month and the five before it, oldest first" do
    assert_equal %w[ 2026-05 2026-06 2026-07 2026-08 2026-09 2026-10 ], @summary.periods.map { |period| period.first_day.strftime("%Y-%m") }
  end

  test "crosses a year boundary" do
    summary = Summary.new(@user.transactions, Period.new("month", today: Date.new(2026, 2, 3)))

    assert_equal %w[ 2025-09 2025-10 2025-11 2025-12 2026-01 2026-02 ], summary.periods.map { |period| period.first_day.strftime("%Y-%m") }
  end

  test "totals income and spent per month in cents, and a month can end below zero" do
    add 789_000, "2026-09-01", "Acme payroll"
    add(-397_712, "2026-09-30", "Rent", categories(:food))
    add 100_000, "2026-07-31", "Acme payroll"
    add(-131_000, "2026-07-01", "Rent")
    add(-500, "2026-10-14", "Coffee")

    totals = @summary.totals.map { |total| [ total.period.first_day.strftime("%Y-%m"), total.income, total.spent, total.net ] }

    assert_equal [
      [ "2026-05", 0, 0, 0 ],
      [ "2026-06", 0, 0, 0 ],
      [ "2026-07", 100_000, 131_000, -31_000 ],
      [ "2026-08", 0, 0, 0 ],
      [ "2026-09", 789_000, 397_712, 391_288 ],
      [ "2026-10", 0, 500, -500 ]
    ], totals
  end

  test "totals one month on its own, even one older than the six" do
    add 12_300, "2026-01-10", "Gig"
    add(-4_500, "2026-01-11", "Lunch")

    total = @summary.total(Period.new("month", today: @today, on: "2026-01-01"))

    assert_equal [ "2026-01", 12_300, 4_500, 7_800 ], [ total.period.first_day.strftime("%Y-%m"), total.income, total.spent, total.net ]
  end

  test "leaves transfers, discarded rows, older months, and other users out" do
    add 50_000, "2026-09-02", "Savings in"
    @user.transactions.last.categorize(Transaction::Categorization.transfer)
    add 70_000, "2026-09-03", "Gift"
    @user.transactions.last.discard
    add 9_999, "2026-04-30", "Too old"
    users(:two).transactions.create!(name: "Theirs", amount_in_cents: 8_888, occurred_on: "2026-09-04")

    assert_equal [ 0, 0 ], @summary.totals[4].then { |total| [ total.income, total.spent ] }
    assert_equal [], @summary.sources(Period.new("month", today: @today, on: "2026-09-01"))
  end

  test "leaves excluded rows out of income, spent, net, and sources" do
    add 50_000, "2026-09-02", "Payroll"
    add(-4_000, "2026-09-03", "Lunch")
    add 30_000, "2026-09-04", "Reimbursement"
    @user.transactions.last.update!(excluded: true)
    add(-20_000, "2026-09-05", "Work trip")
    @user.transactions.last.update!(excluded: true)

    september = Period.new("month", today: @today, on: "2026-09-01")

    assert_equal [ 50_000, 4_000, 46_000 ], @summary.total(september).then { |total| [ total.income, total.spent, total.net ] }
    assert_equal [ [ "Payroll", 50_000 ] ], @summary.sources(september)
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

    sources = @summary.sources(Period.new("month", today: @today, on: "2026-09-01"))

    assert_equal [ [ "Acme payroll", 500_000 ], [ "Acme bonus", 250_000 ], [ "Interest", 30_000 ] ], sources
  end

  test "ranks a month's spending by category" do
    add(-1_200, "2026-09-03", "Bus", categories(:food))
    add(-300, "2026-09-04", "Gum")
    add(-9_000, "2026-10-01", "Other month", categories(:food))

    categories = @summary.categories(Period.new("month", today: @today, on: "2026-09-01"))

    assert_equal [ [ "Food", 1_200 ], [ nil, 300 ] ], categories.map { |category, cents| [ category&.name, cents ] }
  end

  test "lists the current week and the five before it, oldest first, starting on Mondays" do
    summary = Summary.new(@user.transactions, Period.new("week", today: @today))

    assert_equal %w[ 2026-09-07 2026-09-14 2026-09-21 2026-09-28 2026-10-05 2026-10-12 ], summary.periods.map { |period| period.first_day.to_param }
  end

  test "buckets dates into weeks that start on Monday" do
    add 1_000, "2026-10-11", "Sunday gig"
    add 2_000, "2026-10-12", "Monday gig"
    add(-300, "2026-10-18", "Sunday coffee")
    add(-700, "2026-10-12", "Monday coffee")
    add(-900, "2026-09-06", "Too old")

    summary = Summary.new(@user.transactions, Period.new("week", today: @today))

    assert_equal [
      [ "2026-09-07", 0, 0 ],
      [ "2026-09-14", 0, 0 ],
      [ "2026-09-21", 0, 0 ],
      [ "2026-09-28", 0, 0 ],
      [ "2026-10-05", 1_000, 0 ],
      [ "2026-10-12", 2_000, 1_000 ]
    ], summary.totals.map { |total| [ total.period.first_day.to_param, total.income, total.spent ] }
  end

  test "buckets dates into years" do
    add 5_000, "2026-01-01", "This year"
    add(-1_200, "2026-12-31", "Late")
    add 4_000, "2025-12-31", "Last year"
    add(-800, "2021-06-01", "Sixth year back")
    add(-100, "2020-12-31", "Too old")

    summary = Summary.new(@user.transactions, Period.new("year", today: @today))

    assert_equal [
      [ "2021-01-01", 0, 800 ],
      [ "2022-01-01", 0, 0 ],
      [ "2023-01-01", 0, 0 ],
      [ "2024-01-01", 0, 0 ],
      [ "2025-01-01", 4_000, 0 ],
      [ "2026-01-01", 5_000, 1_200 ]
    ], summary.totals.map { |total| [ total.period.first_day.to_param, total.income, total.spent ] }
  end

  private
    def add(cents, occurred_on, name, category = nil)
      @user.transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
