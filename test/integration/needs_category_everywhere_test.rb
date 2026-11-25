require "test_helper"

class NeedsCategoryEverywhereTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 11, 22, 18)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "imported rows without a category carry the dot, count in the chip, and answer the question mark search" do
    import "nocat.csv", "Date,Name,Amount\n2026-11-20,Zzq Hardware,-12.00\n2026-11-20,Zzq Deposit,40.00\n2026-11-21,Zzq Books,-18.50\n"

    get transactions_url(month: "2026-11")

    hardware, books, deposit = %w[ Zzq\ Hardware Zzq\ Books Zzq\ Deposit ].map { @user.transactions.find_by!(name: _1) }
    assert_select "li#transaction_#{hardware.id} [role=img][aria-label='Needs a category']"
    assert_select "li#transaction_#{books.id} [role=img][aria-label='Needs a category']"
    assert_select "li#transaction_#{deposit.id} [role=img][aria-label='Needs a category']", count: 0
    assert_select "a[aria-pressed=false]", text: /Needs a category · 2/

    get transactions_url(month: "2026-11", q: "?")
    assert_select "li#transaction_#{hardware.id}"
    assert_select "li#transaction_#{books.id}"
    assert_select "li#transaction_#{deposit.id}", count: 0
  end

  test "a typed row without a category carries the dot" do
    typed = @user.transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-11-21")

    get transactions_url(month: "2026-11")

    assert_select "li#transaction_#{typed.id} [role=img][aria-label='Needs a category']"
    assert_select "a[aria-pressed=false]", text: /Needs a category · 1/
  end

  test "a row a bank sync matched keeps its dot while it has no category" do
    travel_to Time.utc(2026, 10, 6, 18)
    transactions(:coffee).update!(category: nil)
    activate(connect_simplefin)

    get transactions_url

    assert transactions(:coffee).reload.bank_transaction.matched?
    assert_select "li#transaction_#{transactions(:coffee).id} [role=img][aria-label='Needs a category']"
  end

  test "an excluded row without a category still needs one" do
    excluded = @user.transactions.create!(name: "Refund", amount_in_cents: -300, occurred_on: "2026-11-21", excluded: true)

    get transactions_url(month: "2026-11")

    assert_select "li#transaction_#{excluded.id} [role=img][aria-label='Needs a category']"
  end

  test "the bank review and a new rule leave typed and imported namesakes alone" do
    travel_to Time.utc(2026, 10, 6, 18)
    typed = @user.transactions.create!(name: "Grocery store", amount_in_cents: -4_000, occurred_on: "2026-09-20")
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: -13_550).transaction_id)

    review = @user.simplefin_access.review.needing_category
    assert_includes review, grocery
    assert_not_includes review, typed

    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
    grocery.make_rule

    assert_nil typed.reload.category
    assert typed.needs_category?
  end

  private
    def import(filename, content)
      post imports_url, params: { import: { file: upload(filename, content) } }
      draft = @user.imports.drafts.sole
      patch import_columns_url(draft), params: { import: { columns: draft.columns.kinds, positive_amounts: "income" } }
      post import_transactions_url(draft)
    end
end
