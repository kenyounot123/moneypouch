require "test_helper"

class WelcomeHelperTest < ActionView::TestCase
  include TransactionsHelper

  setup do
    travel_to Time.utc(2026, 10, 15)
  end

  test "counts one transaction in the singular" do
    assert_equal "1 transaction since Oct 2026", transactions_total(1, Date.new(2026, 10, 4))
  end

  test "groups thousands in the count" do
    assert_equal "9,999 transactions since Feb 2025", transactions_total(9999, Date.new(2025, 2, 1))
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

  test "says how much less was spent than the same days last period" do
    assert_equal "↓ $265 (8.6%) vs. Sep 1–15", spending_change(spending(elapsed: 281_600, previous: 308_100))
  end

  test "says how much more was spent, in cents under ten dollars" do
    assert_equal "↑ $4.50 (50%) vs. Sep 1–15", spending_change(spending(elapsed: 1_350, previous: 900))
  end

  test "says when spending matches the period before" do
    assert_equal "Same as Sep 1–15", spending_change(spending(elapsed: 900, previous: 900))
  end

  test "says nothing without spending in the period before" do
    assert_nil spending_change(spending(elapsed: 900, previous: 0))
  end

  test "drops zero cents from the peak caption only" do
    assert_equal "Sep 1 Rent · $1,650", spending_peak(Transaction.new(name: "Rent", amount_in_cents: -165_000, occurred_on: "2026-09-01"))
    assert_equal "Oct 1 Costco · $208.30", spending_peak(Transaction.new(name: "Costco", amount_in_cents: -20_830, occurred_on: "2026-10-01"))
  end

  test "says nothing was spent in the period" do
    assert_equal "Nothing spent this week.", nothing_spent(Period.new("week", today: Date.current))
    assert_equal "Nothing spent in 2026.", nothing_spent(Period.new("year", today: Date.current))
  end

  test "rounds a share and keeps a sliver above zero" do
    assert_equal "58%", share_of(165_000, 283_642)
    assert_equal "<1%", share_of(425, 164_673)
  end

  private
    def spending(elapsed:, previous:)
      Struct.new(:elapsed_total, :previous_total, :period)
        .new(elapsed, previous, Period.new("month", today: Date.current))
    end
end
