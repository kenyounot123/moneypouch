require "test_helper"

class BankAccounts::RulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    activate(connect_simplefin)
    imported(-13_550).categorize(Transaction::Categorization.new(category: categories(:food)))
    imported(-13_550).make_rule
    @rule = BankAccount::Rule.sole
  end

  test "Forget deletes the rule and leaves the rows it filled" do
    delete bank_account_rule_url(@rule.bank_account, @rule), headers: { "HTTP_REFERER" => simplefin_review_url }

    assert_redirected_to simplefin_review_url
    assert_equal 0, BankAccount::Rule.count
    assert_equal [ "Food", "Food" ], [ imported(-13_550), imported(-13_000) ].map { _1.category.name }
  end

  test "another user's rule is not found" do
    sign_in_as(users(:two))

    delete bank_account_rule_url(@rule.bank_account, @rule)

    assert_response :not_found
    assert_equal 1, BankAccount::Rule.count
  end

  private
    def imported(cents)
      Transaction.find(BankTransaction.imported.find_by!(amount_in_cents: cents).transaction_id)
    end
end
