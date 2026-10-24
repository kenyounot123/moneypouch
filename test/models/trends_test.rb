require "test_helper"

class TrendsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.transactions.destroy_all
    @today = Date.new(2026, 10, 15)
  end

  test "lists the 12 calendar months ending with the current one, across a year boundary" do
    trends = trends_on(Date.new(2026, 2, 3))

    assert_equal %w[ 2025-03 2025-04 2025-05 2025-06 2025-07 2025-08 2025-09 2025-10 2025-11 2025-12 2026-01 2026-02 ], trends.periods.map { |period| period.first_day.strftime("%Y-%m") }
  end

  test "totals income and spent per month, the current month so far" do
    add 789_000, "2026-09-01", "Acme payroll"
    add(-397_712, "2026-09-30", "Rent", categories(:food))
    add 100_000, "2025-12-31", "Gig"
    add(-131_000, "2026-01-01", "Rent")
    add(-500, "2026-10-14", "Coffee")

    months = trends_on(@today).months
    nonzero = months.reject { |month| month.income.zero? && month.spent.zero? }.map { |month| [ month.month.first_day.strftime("%Y-%m"), month.income, month.spent ] }

    assert_equal 12, months.size
    assert_equal [ [ "2025-12", 100_000, 0 ], [ "2026-01", 0, 131_000 ], [ "2026-09", 789_000, 397_712 ], [ "2026-10", 0, 500 ] ], nonzero
    assert_equal [ false, true ], [ months[-2].partial?, months[-1].partial? ]
  end

  test "keeps only what is positive and leaves the gap unsaid otherwise" do
    add 500_000, "2026-09-01", "Pay"
    add(-200_000, "2026-09-02", "Rent")
    add 100_000, "2026-08-01", "Pay"
    add(-300_000, "2026-08-02", "Rent")

    months = trends_on(@today).months

    assert_equal [ 300_000, 300_000 ], [ months[-2].net, months[-2].kept ]
    assert_equal [ -200_000, nil ], [ months[-3].net, months[-3].kept ]
  end

  test "totals the year and keeps money only when it is positive" do
    add 500_000, "2026-09-01", "Pay"
    add(-200_000, "2026-09-02", "Rent")

    trends = trends_on(@today)

    assert_equal [ 500_000, 200_000, 300_000 ], [ trends.income, trends.spent, trends.kept ]

    add(-400_000, "2026-10-02", "Trip")

    assert_nil trends_on(@today).kept
  end

  test "a refund bigger than the month's spending reads as nothing spent" do
    add(-1_000, "2026-09-02", "Shoes", categories(:food))
    add 4_000, "2026-09-05", "Shoes back", categories(:food)
    add 50_000, "2026-09-01", "Pay"

    assert_equal 0, trends_on(@today).months[-2].spent
  end

  test "leaves transfers, excluded and discarded rows, other users, and older months out" do
    add 50_000, "2026-09-02", "Savings in"
    @user.transactions.last.categorize(Transaction::Categorization.transfer)
    add 70_000, "2026-09-03", "Gift"
    @user.transactions.last.discard
    add 60_000, "2026-09-04", "Reimbursed"
    @user.transactions.last.update!(excluded: true)
    add 9_999, "2025-09-30", "Too old"
    users(:two).transactions.create!(name: "Theirs", amount_in_cents: 8_888, occurred_on: "2026-09-04")

    assert_equal 0, trends_on(@today).income
  end

  test "is ready once two full months have transactions, whatever else is missing" do
    add 1_000, "2026-10-02", "This month only"
    assert_equal [ 0, false ], [ trends_on(@today).full_months_with_data, trends_on(@today).ready? ]

    add(-500, "2026-08-02", "A full month")
    assert_equal [ 1, false ], [ trends_on(@today).full_months_with_data, trends_on(@today).ready? ]

    add(-500, "2026-05-02", "Another full month")
    assert_equal [ 2, true ], [ trends_on(@today).full_months_with_data, trends_on(@today).ready? ]
  end

  test "sums a category's money per month and lists the largest category first" do
    add(-10_000, "2026-09-02", "Meals", categories(:food))
    add(-5_000, "2026-09-20", "More meals", categories(:food))
    add(-2_000, "2026-10-03", "Lunch", categories(:food))
    add(-30_000, "2026-08-03", "Mystery")
    add 400_000, "2026-09-01", "Pay", categories(:income)

    lines = trends_on(@today).spending_lines

    assert_equal [ "Uncategorized", "Food" ], lines.map(&:label)
    assert_nil lines.first.category
    assert_equal [ 15_000, 2_000, 17_000 ], lines.last.then { |line| [ line.series.fetch(period("2026-09")), line.current, line.total ] }
    assert_equal 12, lines.last.series.size
    assert_equal [ "Income" ], trends_on(@today).income_lines.map(&:label)
    assert_equal 400_000, trends_on(@today).income_lines.first.total
  end

  test "usual is the median of the six full months before this one, empty months counted" do
    [ [ "2026-04", 1_000 ], [ "2026-05", 2_000 ], [ "2026-06", 3_000 ], [ "2026-07", 4_000 ], [ "2026-08", 5_000 ], [ "2026-09", 6_000 ] ].each do |month, cents|
      add(-cents, "#{month}-10", "Meal", categories(:food))
    end
    add(-90_000, "2026-10-02", "Big month so far", categories(:food))
    add(-99_000, "2026-03-10", "Too far back", categories(:food))

    line = trends_on(@today).spending_lines.first

    assert_equal [ 3_500, 90_000 ], [ line.usual, line.current ]
  end

  test "usual counts months with nothing as zero" do
    add(-6_000, "2026-09-10", "Meal", categories(:food))
    add(-8_000, "2026-08-10", "Meal", categories(:food))

    assert_equal 0, trends_on(@today).spending_lines.first.usual

    add(-4_000, "2026-07-10", "Meal", categories(:food))
    add(-9_000, "2026-06-10", "Meal", categories(:food))

    assert_equal 5_000, trends_on(@today).spending_lines.first.usual
  end

  test "usual waits for two of the six months to have money" do
    add(-6_000, "2026-09-10", "Meal", categories(:food))
    add(-8_000, "2026-10-10", "This month", categories(:food))
    add(-8_000, "2026-02-10", "Too far back", categories(:food))

    assert_nil trends_on(@today).spending_lines.first.usual

    add(-2_000, "2026-08-10", "Meal", categories(:food))

    assert_equal 0, trends_on(@today).spending_lines.first.usual
  end

  test "a refund bigger than a category's month leaves that month at zero, and a category with nothing is dropped" do
    add(-1_000, "2026-09-02", "Shoes", categories(:food))
    add 4_000, "2026-09-05", "Shoes back", categories(:food)

    assert_equal [], trends_on(@today).spending_lines
  end

  test "finds a charge that comes once a month under the same name, whatever the case" do
    add(-1_549, "2026-07-03", "Spotify")
    add(-1_549, "2026-08-04", "SPOTIFY")
    add(-1_549, "2026-09-03", "Spotify")
    add(-1_549, "2026-10-03", "spotify")

    charge = trends_on(@today).recurring.sole

    assert_equal [ "spotify", 1_549, nil, 3, Date.new(2026, 10, 3) ], [ charge.name, charge.amount, charge.previous_amount, charge.day, charge.last_on ]
  end

  test "a price change shows the latest amount and the one before" do
    add(-1_549, "2026-07-03", "Spotify")
    add(-1_549, "2026-08-03", "Spotify")
    add(-1_549, "2026-09-03", "Spotify")
    add(-1_799, "2026-10-03", "Spotify")

    charge = trends_on(@today).recurring.sole

    assert_equal [ 1_799, 1_549 ], [ charge.amount, charge.previous_amount ]
  end

  test "needs three distinct months" do
    add(-1_000, "2026-08-03", "Gym")
    add(-1_000, "2026-09-03", "Gym")

    assert_empty trends_on(@today).recurring

    add(-1_000, "2026-10-03", "Gym")

    assert_equal [ "Gym" ], trends_on(@today).recurring.map(&:name)
  end

  test "needs about one charge a month" do
    add(-1_000, "2026-08-03", "Cafe")
    add(-1_000, "2026-08-13", "Cafe")
    add(-1_000, "2026-09-03", "Cafe")
    add(-1_000, "2026-09-13", "Cafe")
    add(-1_000, "2026-10-03", "Cafe")
    add(-1_000, "2026-10-13", "Cafe")

    assert_empty trends_on(@today).recurring
  end

  test "needs amounts within 20% of the median" do
    [ "2026-06-03", "2026-07-03", "2026-08-03", "2026-09-03" ].each { |on| add(-10_000, on, "Insurance") }
    add(-12_000, "2026-10-03", "Insurance")

    assert_equal [ "Insurance" ], trends_on(@today).recurring.map(&:name)

    @user.transactions.find_by!(occurred_on: "2026-10-03").update!(amount_in_cents: -12_001)

    assert_empty trends_on(@today).recurring
  end

  test "lists active charges largest first with their monthly total, and sets aside one not charged in over 45 days" do
    [ "2026-08-03", "2026-09-03", "2026-10-03" ].each { |on| add(-1_549, on, "Spotify") }
    [ "2026-08-20", "2026-09-20" ].each { |on| add(-90_000, on, "Rent") }
    add(-90_000, "2026-07-20", "Rent")
    [ "2026-05-10", "2026-06-10", "2026-07-10", "2026-08-30" ].each { |on| add(-2_000, on, "Old gym") }

    trends = trends_on(@today)

    assert_equal [ "Rent", "Spotify" ], trends.recurring.map(&:name)
    assert_equal 91_549, trends.recurring_total
    assert_equal [ "Old gym" ], trends.stopped.map(&:name)
  end

  test "a charge not yet 45 days old still counts, and 46 days does not" do
    [ "2026-06-01", "2026-07-01", "2026-08-31" ].each { |on| add(-1_000, on, "Gym") }

    assert_equal [ "Gym" ], trends_on(Date.new(2026, 10, 15)).recurring.map(&:name)
    assert_empty trends_on(Date.new(2026, 10, 16)).recurring
  end

  test "leaves income out of the recurring charges" do
    [ "2026-08-01", "2026-09-01", "2026-10-01" ].each { |on| add 200_000, on, "Pay" }

    assert_empty trends_on(@today).recurring
  end

  private
    def trends_on(today)
      Trends.new(@user.transactions, today:)
    end

    def period(month)
      Period.new("month", today: @today, on: "#{month}-01")
    end

    def add(cents, occurred_on, name, category = nil)
      @user.transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
