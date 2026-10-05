require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @transaction = transactions(:coffee)
    sign_in_as(users(:one))
  end

  test "should get index" do
    get transactions_url
    assert_response :success
    assert_select "ul#transactions > li", 2
  end

  test "should update transaction" do
    patch transaction_url(@transaction), params: { transaction: { amount_in_cents: "2999" } }
    assert_redirected_to transactions_url
  end

  test "adds the typed line and redirects back" do
    travel_to Time.utc(2026, 9, 27, 12) do
      assert_difference("Transaction.count", 1) do
        post transactions_url, params: { line: "coffee 5.50", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => root_url }
      end
    end

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert_equal({ "name" => "coffee", "amount_in_cents" => -550, "line" => "coffee 5.50", "occurred_on" => Date.new(2026, 9, 27), "user_id" => users(:one).id },
      Transaction.order(:id).last.slice(:name, :amount_in_cents, :line, :occurred_on, :user_id))
  end

  test "adds one row for a repeated idempotency key" do
    assert_difference("Transaction.count", 1) do
      3.times { post transactions_url, params: { line: "coffee 5.50", idempotency_key: "key-1" } }
    end
  end

  test "saves a new category with the row" do
    assert_difference("Category.count", 1) do
      post transactions_url, params: { line: "lunch 12 #brandnew", idempotency_key: "key-2" }
    end

    assert_equal "brandnew", Transaction.order(:id).last.category.name
  end

  test "keeps an invalid line, shakes the draft, and saves nothing" do
    assert_no_difference("Transaction.count") do
      post transactions_url, params: { line: "coffee", idempotency_key: "key-3" }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=draft] .animate-shake", text: /Type an amount, like 5.50/
  end

  test "undo discards the row, keeps the count, and returns its line" do
    assert_no_difference("Transaction.count") do
      delete transaction_url(@transaction), headers: { "HTTP_REFERER" => root_url }
    end

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert @transaction.reload.discarded_at
    assert_equal "Blue Bottle 5.50", flash[:line]
  end
end
