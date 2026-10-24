require "test_helper"

class Category::SpanTest < ActiveSupport::TestCase
  setup do
    @today = Date.new(2026, 10, 20)
  end

  test "covers the last 3 months ending with this one unless told otherwise" do
    span = Category::Span.from({}, today: @today)

    assert_equal Date.new(2026, 8, 1)..Date.new(2026, 10, 31), span.range
    assert_equal [ 3, true ], [ span.length, span.current? ]
  end

  test "reads 1 or 12 months and falls back to 3 for any other length" do
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 31), Category::Span.from({ months: "1" }, today: @today).range
    assert_equal Date.new(2025, 11, 1)..Date.new(2026, 10, 31), Category::Span.from({ months: "12" }, today: @today).range
    assert_equal 3, Category::Span.from({ months: "7" }, today: @today).length
  end

  test "an earlier month is a span of its own, and this month equals the 1 month choice" do
    july = Category::Span.from({ month: "2026-07" }, today: @today)

    assert_equal Date.new(2026, 7, 1)..Date.new(2026, 7, 31), july.range
    assert_not july.current?
    assert_equal Category::Span.from({ months: "1" }, today: @today), Category::Span.from({ month: "2026-10" }, today: @today)
  end

  test "charts the last 12 months whichever span is open" do
    year = Category::Span.from({ month: "2026-07" }, today: @today).year

    assert_equal Date.new(2025, 11, 1)..Date.new(2026, 10, 31), year.range
    assert_equal 12, year.months.size
  end
end
