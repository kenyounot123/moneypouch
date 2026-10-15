require "test_helper"
require "turbo/broadcastable/test_helper"

class TransactionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  test "a discarded transaction leaves kept and returns after restore" do
    coffee = transactions(:coffee)

    coffee.discard
    assert_equal [ "Paycheck" ], Transaction.kept.pluck(:name)

    coffee.restore
    assert_equal [ "Blue Bottle", "Paycheck" ], Transaction.kept.order(:name).pluck(:name)
  end

  test "tells the owner's open pages to refresh when a row is added, discarded, or restored" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ users(:one), :transactions ], count: 1 do
        users(:one).transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02")
      end
      assert_turbo_stream_broadcasts [ users(:one), :transactions ], count: 1 do
        transactions(:coffee).discard
      end
      assert_turbo_stream_broadcasts [ users(:one), :transactions ], count: 1 do
        transactions(:coffee).restore
      end
    end
  end

  test "never refreshes another user's pages" do
    perform_enqueued_jobs do
      assert_no_turbo_stream_broadcasts [ users(:two), :transactions ] do
        users(:one).transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02")
      end
    end
  end

  test "spent, net, and income reconcile over any set of rows" do
    user = users(:one)
    user.transactions.create!(name: "To savings", amount_in_cents: -10_000, occurred_on: "2026-10-02", transfer: true)
    user.transactions.create!(name: "Refund", amount_in_cents: 1_200, occurred_on: "2026-10-03", category: categories(:food))

    assert_equal [ -650, 200_650, 200_000 ], [ user.transactions.spent, user.transactions.net, user.transactions.income ]

    typed = user.transactions.where(name: [ "Blue Bottle", "Paycheck" ])
    assert_equal [ 550, 199_450, 200_000 ], [ typed.spent, typed.net, typed.income ]
  end

  test "matches a search in the name or the note, ignoring case" do
    transactions(:paycheck).update!(note: "October pay")

    assert_equal [ "Blue Bottle" ], Transaction.matching("blue").pluck(:name)
    assert_equal [ "Paycheck" ], Transaction.matching("OCTOBER").pluck(:name)
    assert_empty Transaction.matching("100%")
    assert_equal [ "Blue Bottle", "Paycheck" ], Transaction.matching(" ").order(:name).pluck(:name)
  end
end
