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
    assert_equal Date.new(2026, 10, 5)..Date.new(2026, 10, 7), period.elapsed
    assert_equal [ 3, 7 ], [ period.day, period.days ]
  end

  test "compares a month with the same days of the month before" do
    previous = Period.new("month", today: Date.new(2026, 9, 27)).previous

    assert_equal Date.new(2026, 8, 1)..Date.new(2026, 8, 27), previous.elapsed
  end

  test "clamps the previous month to its last day" do
    previous = Period.new("month", today: Date.new(2026, 3, 31)).previous

    assert_equal Date.new(2026, 2, 1)..Date.new(2026, 2, 28), previous.elapsed
  end

  test "clamps a leap day to the previous year's February 28" do
    previous = Period.new("year", today: Date.new(2028, 2, 29)).previous

    assert_equal Date.new(2027, 1, 1)..Date.new(2027, 2, 28), previous.elapsed
  end

  test "compares a week with the same weekdays of the week before" do
    previous = Period.new("week", today: Date.new(2026, 10, 5)).previous

    assert_equal Date.new(2026, 9, 28)..Date.new(2026, 9, 28), previous.elapsed
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
    assert_equal Date.new(2026, 3, 1)..Date.new(2026, 3, 31), period.column_range(Date.new(2026, 3, 1))
  end

  test "counts the day of the year" do
    period = Period.new("year", today: Date.new(2026, 10, 5))

    assert_equal [ 278, 365 ], [ period.day, period.days ]
  end
end
