require "test_helper"

class MonthTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 13)

  test "reads a year and month" do
    month = Month.new("2026-09", today: TODAY)

    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), month.range
    assert_equal "2026-09", month.to_param
    assert_equal "September", month.name
    assert_not month.current?
  end

  test "falls back to this month for a missing or unreadable month" do
    assert_equal "2026-10", Month.new(nil, today: TODAY).to_param
    assert_equal "2026-10", Month.new("", today: TODAY).to_param
    assert_equal "2026-10", Month.new("soon", today: TODAY).to_param
    assert_equal "2026-10", Month.new("2026-13", today: TODAY).to_param
  end

  test "clamps a future month to this month" do
    month = Month.new("2027-01", today: TODAY)

    assert_equal "2026-10", month.to_param
    assert month.current?
  end

  test "steps back across a year and forward until this month" do
    january = Month.new("2026-01", today: TODAY)

    assert_equal "2025-12", january.previous.to_param
    assert_equal "2026-02", january.next.to_param
    assert_equal "2026-10", Month.new("2026-09", today: TODAY).next.to_param
    assert_nil Month.new("2026-10", today: TODAY).next
  end
end
