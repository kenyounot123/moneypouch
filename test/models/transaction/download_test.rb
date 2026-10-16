require "test_helper"

class Transaction::DownloadTest < ActiveSupport::TestCase
  test "a download imported into another account brings back every row" do
    one = users(:one)
    one.transactions.create!(name: "Rent", amount_in_cents: -210_000, occurred_on: "2026-10-02", excluded: true)
    one.transactions.create!(name: "Ramen, \"spicy\"", amount_in_cents: -1_825, occurred_on: "2026-10-03", note: "With Jo and Sam", category: categories(:food))
    one.transactions.create!(name: "Blue Bottle", amount_in_cents: -550, occurred_on: "2026-10-01", category: categories(:food))

    import = users(:two).imports.create!(file: upload("download.csv", one.transactions.to_csv))
    import.complete

    assert_predicate import.reload, :completed?
    assert_equal facts(one), facts(users(:two))
  end

  private
    def facts(user)
      user.transactions.includes(:category).order(:occurred_on, :name, :amount_in_cents).map do |transaction|
        [ transaction.occurred_on, transaction.name, transaction.amount_in_cents, transaction.category&.name, transaction.excluded?, transaction.note ]
      end
    end
end
