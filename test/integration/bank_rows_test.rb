require "test_helper"

class BankRowsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
  end

  test "each row names its bank account and a typed row leaves the account blank" do
    activate(connect_simplefin)

    get transactions_url

    assert_select "main section li", 11
    assert_select "li#transaction_#{transactions(:coffee).id} p.w-47\\.5", text: "SimpleFIN Savings"
    assert_select "li#transaction_#{transactions(:paycheck).id} p.w-47\\.5", text: ""
  end

  test "imported rows with no category carry the marker and a matched row does not" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910", amount_in_cents: -13_550).transaction_id)

    get transactions_url

    assert_select "li#transaction_#{grocery.id} div.h-10 div.bg-highlight"
    assert_select "li#transaction_#{transactions(:coffee).id} div.h-10 div.bg-highlight", count: 0
    assert_select "main section div.h-10 div.bg-highlight", 9
  end

  test "the needs-a-category chip counts the marked rows and narrows the month to them" do
    activate(connect_simplefin)

    get transactions_url
    assert_select "a[aria-pressed=false]", text: /Needs a category · 9/

    get transactions_url(needs: "1")
    assert_select "a[aria-pressed=true]", text: /Needs a category · 9/
    assert_select "main section li", 9
    assert_select "main section div.h-10 div.bg-highlight", 9
  end

  test "the account filter narrows to one bank account, or to rows typed in" do
    activate(connect_simplefin)
    savings = BankAccount.find_by!(external_id: "Demo Savings")

    get transactions_url(account: savings.id)
    assert_select "main section li", 5
    assert_select "main section li p.w-47\\.5", text: "SimpleFIN Savings", count: 5
    assert_select "select#account option[selected][value=?]", savings.id.to_s

    get transactions_url(account: "typed")
    assert_select "main section li", 1
    assert_select "li#transaction_#{transactions(:paycheck).id}"
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

  test "the overview says the banks are being checked while a sync runs" do
    access = connect_simplefin
    access.update!(status: :active)

    get root_url
    assert_select "section p", text: /Checking your banks/, count: 0

    access.syncs.create!
    get root_url
    assert_select "section p", text: /Checking your banks/, count: 1
  end

  test "the summary counts rows a rule or a pick already handled" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.imported.find_by!(amount_in_cents: -13_550).transaction_id)
    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
    grocery.make_rule
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
