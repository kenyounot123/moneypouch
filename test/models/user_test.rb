require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "transactions hides a discarded row that discarded_transactions shows" do
    user = users(:one)
    transactions(:coffee).discard

    assert_equal [ "Paycheck" ], user.transactions.pluck(:name)
    assert_equal [ "Blue Bottle" ], user.discarded_transactions.pluck(:name)
  end
end
