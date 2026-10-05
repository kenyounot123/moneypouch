require "test_helper"

class TransactionsHelperTest < ActionView::TestCase
  test "writes money out plain and money in with a plus" do
    assert_equal [ "$5.50", "+$2,400.00" ], [ money(-550), money(240000) ]
  end

  test "writes dates relative to today and adds the year only for another year" do
    travel_to Date.new(2026, 9, 27) do
      assert_equal [ "Today", "Yesterday", "Sep 24", "Sep 24, 2025" ],
        [ Date.new(2026, 9, 27), Date.new(2026, 9, 26), Date.new(2026, 9, 24), Date.new(2025, 9, 24) ].map { |date| relative_date(date) }
      assert_equal [ "Sep 27", "Sep 24, 2025" ], [ short_date(Date.new(2026, 9, 27)), short_date(Date.new(2025, 9, 24)) ]
    end
  end
end
