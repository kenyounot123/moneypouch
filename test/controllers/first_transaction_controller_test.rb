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
    assert_select "h1 + p", text: "Type it on one line. A name and an amount are enough."
    assert_select "p", text: "Only the name and amount are required", count: 0
  end

  test "points to a history before the first transaction" do
    users(:one).transactions.each(&:discard)
    sign_in_as(users(:one))

    get first_transaction_url

    assert_select "p", text: "Already have a history?"
    assert_select "a[href=?]", new_import_path, text: "Import a file"
    assert_select "a[href=?]", new_simplefin_access_path, text: "Connect a bank"
  end

  test "the demo offers no history to bring in" do
    users(:one).transactions.each(&:discard)
    sign_in_as(users(:one))

    with_demo do
      get first_transaction_url
    end

    assert_select "p", text: "Already have a history?", count: 0
    assert_select "a[href=?]", new_import_path, count: 0
    assert_select "a[href=?]", new_simplefin_access_path, count: 0
    assert_select "a[href=?]", root_path, text: "Skip for now"
  end

  test "an empty line asks for a name and an amount and offers the rest" do
    users(:one).transactions.each(&:discard)
    sign_in_as(users(:one))

    get first_transaction_url

    assert_equal "Required", reading("name")
    assert_equal "Required", reading("amount")
    assert_equal "Today", reading("date")
    assert_equal "None yet", reading("category")
    assert_select "[data-reading] .icon--check", count: 0
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

  private
    def reading(label)
      css_select("[data-reading=#{label}] p")[1].text.strip
    end
end
