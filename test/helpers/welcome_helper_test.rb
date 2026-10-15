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

  test "colors the tallest column dark, today gold, and the rest soft" do
    day = Date.new(2026, 10, 3)

    assert_equal "bg-data-strong", column_color(day, day, day)
    assert_equal "bg-highlight", column_color(day, day, day + 1)
    assert_equal "bg-data-soft", column_color(day, day - 1, day + 1)
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


  test "reads a month's totals out loud" do
    total = Summary::Total.new(month: Month.new("2026-09", today: Date.current), income: 789_000, spent: 397_712)

    assert_equal "Sep · income $7,890 · spent $3,977", total_readout(total)
  end
end
