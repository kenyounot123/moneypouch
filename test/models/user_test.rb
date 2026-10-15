require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "transactions hides a discarded row" do
    user = users(:one)
    transactions(:coffee).discard

    assert_equal [ "Paycheck" ], user.transactions.pluck(:name)
  end
end
