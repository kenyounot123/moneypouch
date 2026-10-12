require "test_helper"

class Transactions::RulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    activate(connect_simplefin)
    @grocery = imported(-13_550)
    @grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
  end

  test "Make a rule saves the row's pick for its name and fills that account's waiting rows" do
    post transaction_rule_url(@grocery), headers: { "HTTP_REFERER" => simplefin_review_url }

    assert_redirected_to simplefin_review_url
    assert_equal [ [ "Grocery store", "Food" ] ], BankAccount::Rule.all.map { [ _1.name, _1.category.name ] }
    assert_equal "Food", imported(-13_000).category.name
    assert_nil imported(-17_667).category
  end

  test "another user's transaction is not found" do
    sign_in_as(users(:two))

    post transaction_rule_url(@grocery)

    assert_response :not_found
    assert_equal 0, BankAccount::Rule.count
  end

  private
    def imported(cents)
      Transaction.find(BankTransaction.imported.find_by!(amount_in_cents: cents).transaction_id)
    end
end
