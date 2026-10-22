require "test_helper"
require "turbo/broadcastable/test_helper"

class TransactionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  test "a discarded transaction leaves kept" do
    transactions(:coffee).discard
    assert_equal [ "Paycheck" ], Transaction.kept.pluck(:name)
  end

  test "tells the owner's open pages to refresh when a row is added or discarded" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ users(:one), :transactions ], count: 1 do
        users(:one).transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02")
      end
      assert_turbo_stream_broadcasts [ users(:one), :transactions ], count: 1 do
        transactions(:coffee).discard
      end
    end
  end

  test "never refreshes another user's pages" do
    perform_enqueued_jobs do
      assert_no_turbo_stream_broadcasts [ users(:two), :transactions ] do
        users(:one).transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02")
      end
    end
  end

  test "spent, net, and income reconcile over any set of rows" do
    user = users(:one)
    user.transactions.create!(name: "To savings", amount_in_cents: -10_000, occurred_on: "2026-10-02", transfer: true)
    user.transactions.create!(name: "Refund", amount_in_cents: 1_200, occurred_on: "2026-10-03", category: categories(:food))

    assert_equal [ -650, 200_650, 200_000 ], [ user.transactions.spent, user.transactions.net, user.transactions.income ]

    typed = user.transactions.where(name: [ "Blue Bottle", "Paycheck" ])
    assert_equal [ 550, 199_450, 200_000 ], [ typed.spent, typed.net, typed.income ]
  end

  test "counted leaves out transfers and excluded rows, and net ignores both" do
    user = users(:one)
    savings = user.transactions.create!(name: "To savings", amount_in_cents: -10_000, occurred_on: "2026-10-02", transfer: true)
    trip = user.transactions.create!(name: "Work trip", amount_in_cents: -30_000, occurred_on: "2026-10-03", excluded: true)
    user.transactions.create!(name: "Trip refund", amount_in_cents: 30_000, occurred_on: "2026-10-04", excluded: true)

    assert_equal [ "Blue Bottle", "Paycheck" ], user.transactions.counted.order(:name).pluck(:name)
    assert_equal [ 199_450, 550, 200_000 ], [ user.transactions.net, user.transactions.spent, user.transactions.income ]
    assert_equal [ true, false, false ], [ transactions(:coffee).counted?, savings.counted?, trip.counted? ]
  end

  test "money in offsets its own category: a refund lowers spending, a clawback lowers income" do
    user = users(:two)
    fun = user.categories.create!(name: "Fun")
    user.transactions.create!(name: "Movie", amount_in_cents: -2_000, occurred_on: "2026-10-01", category: fun)
    user.transactions.create!(name: "Movie refund", amount_in_cents: 500, occurred_on: "2026-10-02", category: fun)
    user.transactions.create!(name: "Lunch", amount_in_cents: -1_200, occurred_on: "2026-10-01")
    user.transactions.create!(name: "Pay", amount_in_cents: 100_000, occurred_on: "2026-10-01", category: categories(:income_two))
    user.transactions.create!(name: "Pay clawback", amount_in_cents: -3_000, occurred_on: "2026-10-03", category: categories(:income_two))
    user.transactions.create!(name: "Deposit", amount_in_cents: 4_000, occurred_on: "2026-10-03")
    user.transactions.create!(name: "To savings", amount_in_cents: -50_000, occurred_on: "2026-10-03", transfer: true)

    assert_equal [ "Lunch", "Movie", "Movie refund" ], user.transactions.spending.order(:name).pluck(:name)
    assert_equal [ "Deposit", "Pay", "Pay clawback" ], user.transactions.incoming.order(:name).pluck(:name)
    assert_equal [ 2_700, 101_000, 98_300 ], [ user.transactions.spent, user.transactions.income, user.transactions.net ]
  end

  test "import adds an import's rows for its user once and says how many went in" do
    user = users(:two)
    import = user.imports.create!(file: upload("tea.csv", "Date,Name,Amount,Note\n2024-10-01,Tea,3,\n2024-10-02,Tea,3,hot\n"))

    assert_equal [ 2, 0 ], 2.times.map { user.transactions.import(import.rows, import:) { |row| categories(:income_two) if row.note.present? } }
    assert_equal [ [ "Tea", -300, nil, import.id, nil ], [ "Tea", -300, "hot", import.id, "Income" ] ],
      user.transactions.order(:occurred_on).map { |transaction| [ transaction.name, transaction.amount_in_cents, transaction.note, transaction.import_id, transaction.category&.name ] }
  end

  test "matches a search in the name or the note, ignoring case" do
    transactions(:paycheck).update!(note: "October pay")

    assert_equal [ "Blue Bottle" ], Transaction.matching("blue").pluck(:name)
    assert_equal [ "Paycheck" ], Transaction.matching("OCTOBER").pluck(:name)
    assert_empty Transaction.matching("100%")
    assert_equal [ "Blue Bottle", "Paycheck" ], Transaction.matching(" ").order(:name).pluck(:name)
  end
end
