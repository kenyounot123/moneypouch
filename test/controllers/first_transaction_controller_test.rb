require "test_helper"

class FirstTransactionControllerTest < ActionDispatch::IntegrationTest
  test "shows the composer for a user with no transactions" do
    users(:one).transactions.each(&:discard)
    sign_in_as(users(:one))

    get first_transaction_url

    assert_response :success
    assert_select "h1", text: "What did you last spend on?"
    assert_select "input[aria-label=Add]"
    assert_select "a[href='#{root_path}']", text: "Skip for now"
  end

  test "redirects a user who has transactions to the Overview" do
    sign_in_as(users(:one))

    get first_transaction_url

    assert_redirected_to root_url
  end

  test "adding the first transaction lands on the Overview with the toast" do
    users(:one).transactions.each(&:discard)
    sign_in_as(users(:one))

    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => first_transaction_url }
    assert_redirected_to first_transaction_url
    follow_redirect!
    assert_redirected_to root_url
    follow_redirect!

    added = Transaction.order(:id).last
    assert_select "#toast_transaction_#{added.id}", text: /Added\s+tea\s+\$3.00/
  end
end
