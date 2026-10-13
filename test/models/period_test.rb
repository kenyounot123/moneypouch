require "test_helper"

class PeriodTest < ActiveSupport::TestCase
  test "falls back to month for a missing or unknown kind" do
    assert_equal "month", Period.new(nil, today: Date.new(2026, 10, 5)).kind
    assert_equal "month", Period.new("decade", today: Date.new(2026, 10, 5)).kind
    assert_equal "week", Period.new("week", today: Date.new(2026, 10, 5)).kind
  end

  test "starts the week on Monday" do
    period = Period.new("week", today: Date.new(2026, 10, 7))

    assert_equal Date.new(2026, 10, 5)..Date.new(2026, 10, 11), period.range
    assert_equal [ 3, 7 ], [ period.day, period.days ]
  end

  test "has a column per day for a week or month and per month for a year" do
    assert_equal 7, Period.new("week", today: Date.new(2026, 10, 5)).columns.size
    assert_equal 28, Period.new("month", today: Date.new(2026, 2, 10)).columns.size
    assert_equal Date.new(2026, 1, 1).step(Date.new(2026, 12, 1), 1).select { |date| date.day == 1 },
      Period.new("year", today: Date.new(2026, 10, 5)).columns
  end

  test "puts a date in its month column for a year" do
    period = Period.new("year", today: Date.new(2026, 10, 5))

    assert_equal Date.new(2026, 3, 1), period.column_for(Date.new(2026, 3, 17))
  end

  test "counts the day of the year" do
    period = Period.new("year", today: Date.new(2026, 10, 5))

    assert_equal [ 278, 365 ], [ period.day, period.days ]
  end
end
