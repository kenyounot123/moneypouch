require "test_helper"

class Transaction::DownloadTest < ActiveSupport::TestCase
  test "a download imported into another account brings back every row" do
    one = users(:one)
    one.transactions.create!(name: "Rent", amount_in_cents: -210_000, occurred_on: "2026-10-02", excluded: true)
    one.transactions.create!(name: "Ramen, \"spicy\"", amount_in_cents: -1_825, occurred_on: "2026-10-03", note: "With Jo and Sam\n\n  Split it three ways", category: categories(:food))
    one.transactions.create!(name: "Blue Bottle", amount_in_cents: -550, occurred_on: "2026-10-01", category: categories(:food))
    one.transactions.create!(name: "To savings", amount_in_cents: -50_000, occurred_on: "2026-10-04", transfer: true)

    import = users(:two).imports.create!(file: upload("download.csv", one.transactions.to_csv))
    import.complete

    assert_predicate import.reload, :completed?
    assert_equal facts(one), facts(users(:two))
  end

  test "a download imported into the account it came from adds nothing, typed-in and bank rows alike" do
    one = users(:one)
    activate(connect_simplefin(one))
    one.transactions.create!(name: "Blue Bottle", amount_in_cents: -550, occurred_on: "2026-10-01", category: categories(:food))
    assert one.transactions.typed_in.exists? && one.transactions.joins(:bank_transaction).exists?

    import = one.imports.create!(file: upload("download.csv", one.transactions.to_csv))

    assert_equal [ 0, one.transactions.count ], [ import.tally.adding, import.tally.already_here ]
    assert_no_difference -> { Transaction.count } do
      import.complete
    end
  end

  private
    def facts(user)
      user.transactions.includes(:category).order(:occurred_on, :name, :amount_in_cents).map do |transaction|
        [ transaction.occurred_on, transaction.name, transaction.amount_in_cents, transaction.category&.name, transaction.transfer?, transaction.excluded?, transaction.note ]
      end
    end
end
