require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "a discarded transaction leaves kept and returns after restore" do
    coffee = transactions(:coffee)

    coffee.discard
    assert_equal [ "Paycheck" ], Transaction.kept.pluck(:name)
    assert_equal [ "Blue Bottle" ], Transaction.discarded.pluck(:name)

    coffee.restore
    assert_equal [ "Blue Bottle", "Paycheck" ], Transaction.kept.order(:name).pluck(:name)
    assert_empty Transaction.discarded
  end
end
