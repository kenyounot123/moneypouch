require "test_helper"

class BankRowsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
  end

  test "rows from the bank carry the bank icon and typed rows keep an empty slot" do
    activate(connect_simplefin)

    get transactions_url

    assert_select "ul#transactions > li", 11
    assert_select "ul#transactions > li > div.w-4", 11
    assert_select "ul#transactions > li span.sr-only", text: "From your bank", count: 10
    assert_select "li#transaction_#{transactions(:coffee).id} span.sr-only", text: "From your bank"
    assert_select "li#transaction_#{transactions(:paycheck).id} span.sr-only", count: 0
  end

  test "imported rows with no category carry the marker and a matched row does not" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910", amount_in_cents: -13_550).transaction_id)

    get transactions_url

    assert_select "li#transaction_#{grocery.id} div.bg-highlight"
    assert_select "li#transaction_#{transactions(:coffee).id} div.bg-highlight", count: 0
    assert_select "ul#transactions div.bg-highlight", 9
  end

  test "the overview holds what syncs brought in until Done" do
    activate(connect_simplefin)

    get root_url

    assert_select "#bank_review h2", "From your bank"
    assert_select "#bank_review", text: /9 need a category/
    assert_select "#bank_review li", 3
    assert_select "#bank_review li button[data-action='category-picker#open']", text: "Category", count: 3
    assert_select "#bank_review p", text: "9 new."
    assert_select "#bank_review a[href=?]", simplefin_review_path, text: "Show all"
    assert_select "#bank_review form[action=?] button", simplefin_review_path, text: "Done"

    patch simplefin_review_url
    get root_url
    assert_select "#bank_review", count: 0
  end

  test "the summary counts rows a rule or a pick already handled" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.imported.find_by!(amount_in_cents: -13_550).transaction_id)
    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
    Transaction.find(BankTransaction.imported.find_by!(amount_in_cents: -1_000).transaction_id).categorize(Transaction::Categorization.transfer)

    get root_url

    assert_select "#bank_review", text: /6 need a category/
    assert_select "#bank_review p", text: "9 new. 2 categorized for you, 1 transfer."
  end

  test "a sync that only matched what you typed shows no block" do
    report = simplefin_report
    savings = demo_account(report, "Demo Savings")
    savings["transactions"] = [ savings["transactions"][1] ]
    activate(connect_simplefin, [ "Demo Savings" ], report:)

    get root_url

    assert_select "#bank_review", count: 0
  end
end
