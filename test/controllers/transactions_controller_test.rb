require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @transaction = transactions(:coffee)
    sign_in_as(users(:one))
  end

  test "should get index" do
    get transactions_url
    assert_response :success
  end

  test "should update transaction" do
    patch transaction_url(@transaction), params: { transaction: { amount_in_cents: "2999" } }
    assert_redirected_to transactions_url
  end

  test "should destroy transaction" do
    assert_difference("Transaction.count", -1) do
      delete transaction_url(@transaction)
    end

    assert_redirected_to transactions_url
  end
end
