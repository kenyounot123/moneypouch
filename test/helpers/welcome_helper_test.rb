require "test_helper"

class WelcomeHelperTest < ActionView::TestCase
  include TransactionsHelper

  setup do
    travel_to Time.utc(2026, 10, 15)
  end

  test "heads each period" do
    assert_equal "Spent this week", spent_heading(Period.new("week", today: Date.current))
    assert_equal "Spent in October", spent_heading(Period.new("month", today: Date.current))
    assert_equal "Spent in 2026", spent_heading(Period.new("year", today: Date.current))
  end

  test "names a span of days compactly" do
    assert_equal "Sep 28", span(Date.new(2026, 9, 28)..Date.new(2026, 9, 28))
    assert_equal "Aug 1–27", span(Date.new(2026, 8, 1)..Date.new(2026, 8, 27))
    assert_equal "Sep 28–Oct 4", span(Date.new(2026, 9, 28)..Date.new(2026, 10, 4))
    assert_equal "Jan 1–Oct 15, 2025", span(Date.new(2025, 1, 1)..Date.new(2025, 10, 15))
  end

  test "says nothing was spent in the period" do
    assert_equal "Nothing spent this week.", nothing_spent(Period.new("week", today: Date.current))
    assert_equal "Nothing spent in 2026.", nothing_spent(Period.new("year", today: Date.current))
  end

  test "rounds a share and keeps a sliver above zero" do
    assert_equal "58%", share_of(165_000, 283_642)
    assert_equal "<1%", share_of(425, 164_673)
  end

  test "scales a bar against the tallest and never draws less than four pixels" do
    assert_equal [ 136, 68, 4 ], [ column_height(500, 500), column_height(250, 500), column_height(1, 500) ]
    assert_equal [ 130, 65 ], [ summary_bar_height(500, 500), summary_bar_height(250, 500) ]
  end

  test "colors the tallest column dark, today a step lighter, and the rest soft" do
    day = Date.new(2026, 10, 3)

    assert_equal "bg-data-strong", column_color(day, day, day)
    assert_equal "bg-data", column_color(day, day, day + 1)
    assert_equal "bg-data-soft", column_color(day, day - 1, day + 1)
  end

  test "colors uncategorized spending gold and the biggest category dark" do
    assert_equal [ "bg-highlight", "bg-highlight", "bg-data-strong", "bg-data" ],
      [ category_color(nil, 0), category_color(nil, 3), category_color(categories(:food), 0), category_color(categories(:food), 1) ]
  end

  test "labels every column of a short period" do
    week = Period.new("week", today: Date.current)
    columns = Spending.new(users(:one).transactions, week).columns

    assert_equal [ [ "Oct 12", 1 ], [ "Oct 13", 1 ], [ "Oct 14", 1 ], [ "Oct 15", 1 ], [ "Oct 16", 1 ], [ "Oct 17", 1 ], [ "Oct 18", 1 ] ], column_labels(week, columns)
  end

  test "labels every seventh column of a long period under the columns it spans" do
    month = Period.new("month", today: Date.current)
    columns = Spending.new(users(:one).transactions, month).columns

    assert_equal [ [ "Oct 1", 7 ], [ "Oct 8", 7 ], [ "Oct 15", 7 ], [ "Oct 22", 7 ], [ "Oct 29", 3 ] ], column_labels(month, columns)
  end

  test "labels a year by month name" do
    year = Period.new("year", today: Date.current)
    columns = Spending.new(users(:one).transactions, year).columns

    assert_equal [ [ "Jan", 1 ], [ "Feb", 1 ], [ "Mar", 1 ], [ "Apr", 1 ], [ "May", 1 ], [ "Jun", 1 ] ], column_labels(year, columns).first(6)
    assert_equal 12, column_labels(year, columns).size
  end

  test "rounds money to whole dollars" do
    assert_equal [ "$7,890", "$3,977", "$0" ], [ whole_spent(789_000), whole_spent(397_712), whole_spent(0) ]
    assert_equal "$1", whole_spent(50)
  end

  test "signs a net, with a real minus for a loss" do
    assert_equal [ "+$3,913", "−$310", "$0" ], [ whole_net(391_288), whole_net(-31_000), whole_net(0) ]
    assert_equal [ "+$3,912.88", "−$310.00", "$0.00" ], [ exact_net(391_288), exact_net(-31_000), exact_net(0) ]
  end

  test "abbreviates a period by its kind" do
    today = Date.current

    assert_equal "Sep 7", period_abbreviation(Period.new("week", today:, on: "2026-09-09"))
    assert_equal "Sep", period_abbreviation(Period.new("month", today:, on: "2026-09-09"))
    assert_equal "2025", period_abbreviation(Period.new("year", today:, on: "2025-09-09"))
    assert_equal "Dec 29", period_abbreviation(Period.new("week", today:, on: "2026-01-01"))
  end

  test "names a period by its kind" do
    today = Date.current

    assert_equal "Sep 7–13", period_name(Period.new("week", today:, on: "2026-09-09"))
    assert_equal "Sep 28–Oct 4", period_name(Period.new("week", today:, on: "2026-10-01"))
    assert_equal "September", period_name(Period.new("month", today:, on: "2026-09-09"))
    assert_equal "2025", period_name(Period.new("year", today:, on: "2025-09-09"))
  end

  test "reads a month's totals out loud" do
    total = Summary::Total.new(period: Period.new("month", today: Date.current, on: "2026-09-01"), income: 789_000, spent: 397_712)

    assert_equal "Sep · income $7,890 · spent $3,977", total_readout(total)
  end

  test "reads a week's and a year's totals out loud" do
    week = Summary::Total.new(period: Period.new("week", today: Date.current, on: "2026-10-01"), income: 5_000, spent: 1_250)
    this_week = Summary::Total.new(period: Period.new("week", today: Date.current), income: 0, spent: 4_000)
    year = Summary::Total.new(period: Period.new("year", today: Date.current, on: "2025-05-05"), income: 9_000_000, spent: 6_500_000)
    this_year = Summary::Total.new(period: Period.new("year", today: Date.current), income: 100, spent: 0)

    assert_equal "Sep 28 · income $50 · spent $13", total_readout(week)
    assert_equal "Oct 12 · income $0 · spent $40", total_readout(this_week)
    assert_equal "2025 · income $90,000 · spent $65,000", total_readout(year)
    assert_equal "2026 · income $1 · spent $0", total_readout(this_year)
  end

  test "colors flow segments dark, medium, then soft" do
    assert_equal [ "bg-data-strong", "bg-data", "bg-data-soft" ], [ segment_color(0), segment_color(1), segment_color(2) ]
  end

  test "folds all but the first two flow rows into one more segment" do
    assert_equal [ [ "Rent", 500 ] ], flow_segments([ [ "Rent", 500 ] ])
    assert_equal [ [ "Rent", 500 ], [ "Food", 300 ] ], flow_segments([ [ "Rent", 500 ], [ "Food", 300 ] ])
    assert_equal [ [ "Rent", 500 ], [ "Food", 300 ], [ "2 more", 150 ] ], flow_segments([ [ "Rent", 500 ], [ "Food", 300 ], [ "Gum", 100 ], [ "Bus", 50 ] ])
  end
end
