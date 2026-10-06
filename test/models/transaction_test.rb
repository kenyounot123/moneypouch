require "test_helper"
require "turbo/broadcastable/test_helper"

class TransactionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  test "a discarded transaction leaves kept and returns after restore" do
    coffee = transactions(:coffee)

    coffee.discard
    assert_equal [ "Paycheck" ], Transaction.kept.pluck(:name)
    assert_equal [ "Blue Bottle" ], Transaction.discarded.pluck(:name)

    coffee.restore
    assert_equal [ "Blue Bottle", "Paycheck" ], Transaction.kept.order(:name).pluck(:name)
    assert_empty Transaction.discarded
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
end
