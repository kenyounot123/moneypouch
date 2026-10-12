require "test_helper"

class BankAccount::RuleTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    @user = users(:one)
    @access = connect_simplefin
    activate(@access)
    @groceries = @user.categories.create!(name: "Groceries")
  end

  test "categorizing an imported row fills that account's same-name rows that still need a category" do
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.new(category: @groceries))

    assert_equal [ "Groceries", "Groceries" ], categories_of("Demo Savings", "grocery store")
    assert_equal [ nil, nil ], categories_of("Demo Checking", "grocery store")
    assert_equal [ [ "Grocery store", "grocery store", "Groceries", false ] ], rules
  end

  test "a rule never overwrites a category or a transfer" do
    imported("Demo Savings", -13_000).update!(category: categories(:food))

    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.transfer)

    assert_equal [ [ -13_550, nil, true ], [ -13_000, "Food", false ] ],
      bank_rows("Demo Savings", "grocery store").map { |transaction| [ transaction.amount_in_cents, transaction.category&.name, transaction.transfer? ] }
  end

  test "picking again changes the rule but leaves rows it already filled" do
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.new(category: @groceries))
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.new(category: categories(:food)))

    assert_equal [ [ "Grocery store", "grocery store", "Food", false ] ], rules
    assert_equal "Groceries", imported("Demo Savings", -13_000).category.name
  end

  test "a typed row or a cleared category teaches nothing" do
    transactions(:coffee).reload.categorize(Transaction::Categorization.new(category: @groceries))
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.none)

    assert_empty rules
  end

  test "the next sync brings same-name rows in by the rule, ahead of name history" do
    @user.transactions.create!(name: "Grocery store", amount_in_cents: -4000, occurred_on: Date.new(2026, 9, 1), category: categories(:food))
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.transfer)

    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << demo_account(report, "Demo Savings")["transactions"][2].merge("id" => "next-week", "amount" => "-99.00")
    sync_again(@access, report:)

    arrived = imported("Demo Savings", -9_900)
    assert_equal [ true, nil, false ], [ arrived.transfer?, arrived.category, arrived.needs_category? ]
  end

  test "a sync reads each account's rules once, not once per row" do
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.new(category: @groceries))
    report = simplefin_report
    BankSyncTestHelper::DEMO_ACCOUNTS.each do |account|
      rows = demo_account(report, account)["transactions"]
      rows << rows[2].merge("id" => "#{account}-a", "amount" => "-91.00") << rows[2].merge("id" => "#{account}-b", "amount" => "-92.00")
    end

    assert_queries_match(/FROM "bank_account_rules"/, count: 2) do
      sync_again(@access, report:)
    end
    assert_equal [ "Groceries", "Groceries", nil, nil ],
      [ imported("Demo Savings", -9_100), imported("Demo Savings", -9_200), imported("Demo Checking", -9_100), imported("Demo Checking", -9_200) ].map { _1.category&.name }
  end

  private
    def imported(account, cents)
      BankTransaction.imported.joins(:bank_account).find_by!(bank_accounts: { external_id: account }, amount_in_cents: cents).then { Transaction.find(_1.transaction_id) }
    end

    def bank_rows(account, name_key)
      BankAccount.find_by!(external_id: account).transactions_named(name_key).order(:amount_in_cents).to_a
    end

    def categories_of(account, name_key)
      bank_rows(account, name_key).map { |transaction| transaction.category&.name }
    end

    def rules
      BankAccount::Rule.order(:id).map { |rule| [ rule.name, rule.name_key, rule.category&.name, rule.transfer ] }
    end
end
