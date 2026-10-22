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

  test "steps back to a past period by an ISO date or a Date" do
    today = Date.new(2026, 10, 15)

    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), Period.new("month", today:, on: "2026-09-17").range
    assert_equal Date.new(2026, 9, 7)..Date.new(2026, 9, 13), Period.new("week", today:, on: Date.new(2026, 9, 9)).range
    assert_equal Date.new(2025, 1, 1)..Date.new(2025, 12, 31), Period.new("year", today:, on: "2025-06-01").range
    assert_equal Date.new(2026, 9, 1), Period.new("month", today:, on: "2026-09-17").first_day
  end

  test "clamps a future date to today and falls back to today for an unparsable one" do
    today = Date.new(2026, 10, 15)

    assert_equal Date.new(2026, 10, 1), Period.new("month", today:, on: "2030-01-01").first_day
    assert_equal Date.new(2026, 10, 12), Period.new("week", today:, on: "2026-12-25").first_day
    assert_equal Date.new(2026, 10, 1), Period.new("month", today:, on: "soon").first_day
    assert_equal Date.new(2026, 10, 1), Period.new("month", today:, on: "2026-13-01").first_day
    assert_equal Date.new(2026, 10, 1), Period.new("month", today:, on: "").first_day
  end

  test "keeps counting the day from today inside a past period" do
    period = Period.new("month", today: Date.new(2026, 10, 15), on: "2026-09-01")

    assert_equal [ 45, 30 ], [ period.day, period.days ]
  end

  test "steps to the previous period across a year boundary" do
    today = Date.new(2026, 1, 6)

    assert_equal Date.new(2025, 12, 29), Period.new("week", today:).previous.first_day
    assert_equal Date.new(2025, 12, 1), Period.new("month", today:).previous.first_day
    assert_equal Date.new(2025, 1, 1), Period.new("year", today:).previous.first_day
    assert_equal Date.new(2025, 12, 22), Period.new("week", today:).previous.previous.first_day
  end

  test "is current only while its range covers today" do
    today = Date.new(2026, 10, 15)

    assert Period.new("month", today:).current?
    assert Period.new("week", today:, on: "2026-10-12").current?
    assert_not Period.new("month", today:).previous.current?
    assert_not Period.new("year", today:).previous.current?
  end

  test "equals a period of the same kind and range" do
    today = Date.new(2026, 10, 15)

    assert_equal Period.new("month", today:, on: "2026-09-01"), Period.new("month", today:, on: "2026-09-20")
    assert_equal Period.new("month", today:).previous, Period.new("month", today:, on: "2026-09-30")
    assert_equal Period.new("month", today:, on: "2026-09-01").hash, Period.new("month", today:, on: "2026-09-20").hash
    assert_not_equal Period.new("month", today:), Period.new("month", today:).previous
    assert_not_equal Period.new("week", today:, on: "2026-10-01"), Period.new("month", today:, on: "2026-10-01")
    assert_not_equal Period.new("month", today:), nil
  end

  test "reads the Transactions page's year and month" do
    month = Period.month("2026-09", today: Date.new(2026, 10, 13))

    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), month.range
    assert_not month.current?
  end

  test "falls back to this month for a missing or unreadable month, and clamps a future one" do
    [ nil, "", "soon", "2026-13", "2027-01" ].each do |param|
      assert_equal Date.new(2026, 10, 1), Period.month(param, today: Date.new(2026, 10, 13)).first_day, param.inspect
    end
  end

  test "steps forward until the current period" do
    january = Period.month("2026-01", today: Date.new(2026, 10, 13))

    assert_equal Date.new(2025, 12, 1), january.previous.first_day
    assert_equal Date.new(2026, 2, 1), january.next.first_day
    assert_equal Date.new(2026, 10, 1), Period.month("2026-09", today: Date.new(2026, 10, 13)).next.first_day
    assert_nil Period.month("2026-10", today: Date.new(2026, 10, 13)).next
    assert_equal Date.new(2026, 10, 12), Period.new("week", today: Date.new(2026, 10, 13), on: "2026-10-05").next.first_day
  end
end
