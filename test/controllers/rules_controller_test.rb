require "test_helper"

class RulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    activate(connect_simplefin)
    added_by_bank(-13_550).categorize(Transaction::Categorization.new(category: categories(:food)))
    added_by_bank(-13_550).make_rule
    @rule = Rule.sole
  end

  test "Forget deletes the rule and leaves the rows it filled" do
    delete rule_url(@rule), headers: { "HTTP_REFERER" => simplefin_review_url }

    assert_redirected_to simplefin_review_url
    assert_equal 0, Rule.count
    assert_equal [ "Food", "Food" ], [ added_by_bank(-13_550), added_by_bank(-13_000) ].map { _1.category.name }
  end

  test "another user's rule is not found" do
    sign_in_as(users(:two))

    delete rule_url(@rule)

    assert_response :not_found
    assert_equal 1, Rule.count
  end

  private
    def added_by_bank(cents)
      Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: cents).transaction_id)
    end
end
