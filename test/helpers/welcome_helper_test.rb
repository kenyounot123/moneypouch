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
end
