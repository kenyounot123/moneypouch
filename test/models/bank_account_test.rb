require "test_helper"

class BankAccountTest < ActiveSupport::TestCase
  test "the full name leads with the bank unless the account name already names it" do
    assert_equal [ "Chase CREDIT CARD", "Chase Sapphire Preferred", "SimpleFIN Savings", "Checking" ],
      [ [ "Chase", "CREDIT CARD" ], [ "JPMorgan Chase", "Chase Sapphire Preferred" ], [ "SimpleFIN Bridge", "SimpleFIN Savings" ], [ nil, "Checking" ] ]
        .map { |institution, name| BankAccount.new(institution:, name:).full_name }
  end
end
