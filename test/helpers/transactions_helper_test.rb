require "test_helper"

class TransactionsHelperTest < ActionView::TestCase
  include MoneyHelper

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
