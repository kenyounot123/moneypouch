require "test_helper"

class RuleTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    @user = users(:one)
    @access = connect_simplefin
    activate(@access)
    @groceries = @user.categories.create!(name: "Groceries")
  end

  test "a pick changes only that row and saves no rule" do
    imported("Demo Savings", -13_550).categorize(Transaction::Categorization.new(category: @groceries))

    assert_equal [ "Groceries", nil ], categories_of("Demo Savings", "grocery store")
    assert_empty rules
  end

  test "making a rule fills same-name rows on every account that still need a category" do
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.new(category: @groceries))

    grocery.make_rule

    assert_equal [ "Groceries", "Groceries" ], categories_of("Demo Savings", "grocery store")
    assert_equal [ "Groceries", "Groceries" ], categories_of("Demo Checking", "grocery store")
    assert_equal [ [ "Grocery store", "grocery store", "Groceries", false ] ], rules
  end

  test "a rule never overwrites a category or a transfer" do
    imported("Demo Savings", -13_000).update!(category: categories(:food))
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.transfer)

    grocery.make_rule

    assert_equal [ [ -13_550, nil, true ], [ -13_000, "Food", false ] ],
      bank_rows("Demo Savings", "grocery store").map { |transaction| [ transaction.amount_in_cents, transaction.category&.name, transaction.transfer? ] }
  end

  test "making the rule again changes it but leaves rows it already filled" do
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.new(category: @groceries))
    grocery.make_rule
    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))

    grocery.make_rule

    assert_equal [ [ "Grocery store", "grocery store", "Food", false ] ], rules
    assert_equal "Groceries", imported("Demo Savings", -13_000).category.name
  end

  test "a typed row or a cleared category makes no rule" do
    coffee = transactions(:coffee).reload
    coffee.categorize(Transaction::Categorization.new(category: @groceries))
    coffee.make_rule
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.none)
    grocery.make_rule

    assert_empty rules
  end

  test "a row offers a rule until the user remembers that pick for its name" do
    grocery = imported("Demo Savings", -13_550)
    assert_not grocery.offers_rule?

    grocery.categorize(Transaction::Categorization.new(category: @groceries))
    assert grocery.offers_rule?
    assert_not transactions(:coffee).reload.offers_rule?

    grocery.make_rule
    assert_not grocery.offers_rule?

    grocery.categorize(Transaction::Categorization.transfer)
    assert grocery.offers_rule?
  end

  test "counts the same-name rows on every account still waiting for a category" do
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.new(category: @groceries))

    assert_equal 3, grocery.waiting_namesake_count

    grocery.make_rule
    assert_equal 0, grocery.waiting_namesake_count
  end

  test "the next sync brings same-name rows in by the rule, ahead of name history" do
    @user.transactions.create!(name: "Grocery store", amount_in_cents: -4000, occurred_on: Date.new(2026, 9, 1), category: categories(:food))
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.transfer)
    grocery.make_rule

    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << demo_account(report, "Demo Savings")["transactions"][2].merge("id" => "next-week", "amount" => "-99.00")
    sync_again(@access, report:)

    arrived = imported("Demo Savings", -9_900)
    assert_equal [ true, nil, false ], [ arrived.transfer?, arrived.category, arrived.needs_category? ]
  end

  test "a rule reaches rows of another account on the next sync" do
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.new(category: @groceries))
    grocery.make_rule
    report = simplefin_report
    checking = demo_account(report, "Demo Checking")["transactions"]
    checking << checking[2].merge("id" => "next-week", "amount" => "-99.00")
    sync_again(@access, report:)

    assert_equal "Groceries", imported("Demo Checking", -9_900).category.name
  end

  test "a sync reads the user's rules once, not once per account or row" do
    grocery = imported("Demo Savings", -13_550)
    grocery.categorize(Transaction::Categorization.new(category: @groceries))
    grocery.make_rule
    report = simplefin_report
    BankSyncTestHelper::DEMO_ACCOUNTS.each do |account|
      rows = demo_account(report, account)["transactions"]
      rows << rows[2].merge("id" => "#{account}-a", "amount" => "-91.00") << rows[2].merge("id" => "#{account}-b", "amount" => "-92.00")
    end

    assert_queries_match(/FROM "rules"/, count: 1) do
      sync_again(@access, report:)
    end
    assert_equal [ "Groceries", "Groceries", "Groceries", "Groceries" ],
      [ imported("Demo Savings", -9_100), imported("Demo Savings", -9_200), imported("Demo Checking", -9_100), imported("Demo Checking", -9_200) ].map { _1.category&.name }
  end

  private
    def imported(account, cents)
      BankTransaction.imported.joins(:bank_account).find_by!(bank_accounts: { external_id: account }, amount_in_cents: cents).then { Transaction.find(_1.transaction_id) }
    end

    def bank_rows(account, name_key)
      @user.transactions_named(name_key).joins(:bank_transaction).where(bank_transactions: { bank_account_id: BankAccount.where(external_id: account).select(:id) }).order(:amount_in_cents).to_a
    end

    def categories_of(account, name_key)
      bank_rows(account, name_key).map { |transaction| transaction.category&.name }
    end

    def rules
      Rule.order(:id).map { |rule| [ rule.name, rule.name_key, rule.category&.name, rule.transfer ] }
    end
end
