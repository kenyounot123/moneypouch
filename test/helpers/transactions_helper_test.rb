require "test_helper"

class TransactionsHelperTest < ActionView::TestCase
  test "writes money out plain and money in with a plus" do
    assert_equal [ "$5.50", "+$2,400.00" ], [ money(-550), money(240000) ]
  end

  test "colors money in green and leaves the rest to the caller" do
    assert_equal [ "text-success", nil, nil ], [ money_color(240000), money_color(-550), money_color(0) ]
    assert_equal [ "text-success", "text-tertiary", "text-tertiary" ],
      [ money_color(240000, otherwise: "text-tertiary"), money_color(-550, otherwise: "text-tertiary"), money_color(0, otherwise: "text-tertiary") ]
  end

  test "colors a counted amount green when money comes in and an uncounted one tertiary" do
    income = Transaction.new(amount_in_cents: 240000)
    spend = Transaction.new(amount_in_cents: -550)
    free = Transaction.new(amount_in_cents: 0)
    transfer = Transaction.new(amount_in_cents: 240000, transfer: true)
    excluded = Transaction.new(amount_in_cents: 240000, excluded: true)

    assert_equal [ "text-success", nil, nil, "text-tertiary", "text-tertiary" ],
      [ income, spend, free, transfer, excluded ].map { |transaction| amount_color(transaction) }
  end

  test "writes a shortcut with the command key on a Mac and Ctrl elsewhere" do
    request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
    assert_equal [ "⌘Z", "⌘K" ], [ shortcut("Z"), shortcut("K") ]

    request.user_agent = "Mozilla/5.0 (X11; Linux x86_64)"
    assert_equal [ "Ctrl Z", "Ctrl K" ], [ shortcut("Z"), shortcut("K") ]
  end

  test "writes dates relative to today and adds the year only for another year" do
    travel_to Date.new(2026, 9, 27) do
      assert_equal [ "Today", "Yesterday", "Sep 24", "Sep 24, 2025" ],
        [ Date.new(2026, 9, 27), Date.new(2026, 9, 26), Date.new(2026, 9, 24), Date.new(2025, 9, 24) ].map { |date| relative_date(date) }
      assert_equal [ "Sep 27", "Sep 24, 2025" ], [ short_date(Date.new(2026, 9, 27)), short_date(Date.new(2025, 9, 24)) ]
    end
  end
end
