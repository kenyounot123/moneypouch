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
    assert_select "li#transaction_#{transactions(:coffee).id} [data-field=account]", text: "SimpleFIN Savings"
    assert_select "li#transaction_#{transactions(:paycheck).id} [data-field=account]", count: 0
  end

  test "rows added by the bank with no category carry the marker and a matched row does not" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910", amount_in_cents: -13_550).transaction_id)

    get transactions_url

    assert_select "li#transaction_#{grocery.id} [role=img][aria-label='Needs a category']"
    assert_select "li#transaction_#{transactions(:coffee).id} [role=img][aria-label='Needs a category']", count: 0
    assert_select "main section [role=img][aria-label='Needs a category']", 9
  end

  test "money in from the bank waits for a category until Income is picked" do
    activate(connect_simplefin)
    deposit = Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: 196_000).transaction_id)

    get transactions_url
    assert_select "li#transaction_#{deposit.id} [role=img][aria-label='Needs a category']"

    patch transaction_categorization_url(deposit), params: { categorization: { category: "Income" } }
    get transactions_url

    assert_select "li#transaction_#{deposit.id} [role=img][aria-label='Needs a category']", count: 0
    assert_select "li#transaction_#{deposit.id} button[data-action='category-picker#open']", text: "Income"
    assert_select "a[aria-pressed=false]", text: /Needs a category · 8/
  end

  test "the needs-a-category chip counts the marked rows and narrows the month to them" do
    activate(connect_simplefin)

    get transactions_url
    assert_select "a[aria-pressed=false]", text: /Needs a category · 9/

    get transactions_url(q: "?")
    assert_select "a[aria-pressed=true]", text: /Needs a category · 9/
    assert_select "[data-field=token][data-kind=status]", text: /Needs a category/
    assert_select "main section li", 9
    assert_select "main section [role=img][aria-label='Needs a category']", 9
  end

  test "the account token narrows to one bank account, or to rows typed in" do
    activate(connect_simplefin)

    get transactions_url(q: "in:savings")
    assert_select "main section li", 5
    assert_select "main section li [data-field=account]", text: "SimpleFIN Savings", count: 5
    assert_select "[data-field=token][data-kind=account]", text: /SimpleFIN Savings/

    get transactions_url(q: "in:typed")
    assert_select "main section li", 1
    assert_select "li#transaction_#{transactions(:paycheck).id}"
  end

  test "a row's bank account pivots the search to that account, and the page offers it by name" do
    activate(connect_simplefin)
    savings = BankAccount.find_by!(external_id: "Demo Savings")
    row = users(:one).transactions.from_bank_account(savings).first

    get transactions_url(q: "in:savings")

    assert_select "li#transaction_#{row.id} [data-field=account] [data-action='click->search#pivot'][data-search-token-param=?][title=?]", "in:simplefinsavings", "Show all in SimpleFIN Savings"
    assert_select "main[data-search-accounts-value*=?]", "in:simplefinchecking"
  end

  test "the overview holds what syncs brought in until Done" do
    activate(connect_simplefin)

    get root_url

    assert_select "#bank_review h2", "From your bank"
    assert_select "#bank_review span[aria-label='9 need a category']", text: "9"
    assert_select "#bank_review li", 3
    assert_select "#bank_review li button[data-action='category-picker#open']", text: "Category", count: 3
    assert_select "#bank_review li span", text: /· SimpleFIN (Savings|Checking)\z/, count: 3
    assert_select "#bank_review a[href=?][data-turbo-frame=_top]", simplefin_review_path, text: "Show all", count: 1
    assert_select "#bank_review form", count: 0

    post simplefin_review_completion_url
    get root_url
    assert_select "#bank_review span[aria-label='9 need a category']", text: "9"
    assert_select "#bank_review li", 3
  end

  test "the overview drops the block after Done once nothing needs a category" do
    activate(connect_simplefin)
    Simplefin::Sync.added_transactions.update_all(category_id: categories(:food).id)

    post simplefin_review_completion_url
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

  test "the count badge follows the rows a rule or a pick already handled" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: -13_550).transaction_id)
    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
    grocery.make_rule
    Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: -1_000).transaction_id).categorize(Transaction::Categorization.transfer)

    get root_url

    assert_select "#bank_review span[aria-label='4 need a category']", text: "4"
  end

  test "the count badge says one row needs a category in the singular" do
    activate(connect_simplefin)
    BankTransaction.unmatched.find_each do |bank_transaction|
      Transaction.find(bank_transaction.transaction_id).categorize(Transaction::Categorization.transfer)
    end
    Transaction.find(BankTransaction.unmatched.first.transaction_id).categorize(Transaction::Categorization.none)

    get root_url

    assert_select "#bank_review span[aria-label='1 needs a category']", text: "1"
  end

  test "the count badge is absent when nothing needs a category" do
    activate(connect_simplefin)
    BankTransaction.unmatched.find_each do |bank_transaction|
      Transaction.find(bank_transaction.transaction_id).categorize(Transaction::Categorization.transfer)
    end

    get root_url

    assert_select "#bank_review h2", "From your bank"
    assert_select "#bank_review span[aria-label]", count: 0
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
