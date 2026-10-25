require "test_helper"

class Transaction::ListingTest < ActiveSupport::TestCase
  setup do
    @month = Period.month("2026-10", today: Date.new(2026, 10, 15))
  end

  test "totals the month's transactions" do
    listing = listing_for("")

    assert_equal [ 2, 550, 200_000, 199_450 ], [ listing.count, listing.spent, listing.income, listing.net ]
    assert_equal({ Date.new(2026, 10, 1) => 199_450 }, listing.day_totals)
  end

  test "day totals leave out transfers and excluded rows, so a day of only those reads zero" do
    user = users(:one)
    user.transactions.create!(name: "To savings", amount_in_cents: -10_000, occurred_on: "2026-10-02", transfer: true)
    user.transactions.create!(name: "Work trip", amount_in_cents: -30_000, occurred_on: "2026-10-02", excluded: true)
    user.transactions.create!(name: "Lunch", amount_in_cents: -1_200, occurred_on: "2026-10-03")
    listing = listing_for("")

    assert_equal [ 199_450, -1_200, 0 ], [ Date.new(2026, 10, 1), Date.new(2026, 10, 3), Date.new(2026, 10, 2) ].map { |date| listing.day_totals[date] }
    assert_equal listing.net, listing.day_totals.values.sum
  end

  test "narrows by name, note and category" do
    assert_equal [ "Blue Bottle" ], listing_for("bottle").transactions.map(&:name)
    assert_equal [ "Paycheck" ], listing_for("#income").transactions.map(&:name)
    assert_equal [ "Blue Bottle", "Paycheck" ], listing_for("#income #food").transactions.map(&:name).sort
  end

  test "typed-in rows are every row without a bank" do
    assert_equal 2, listing_for("in:typed").count
  end

  test "a search spans every month, unless it names its dates" do
    users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-09-30")

    assert_equal [ "Rent" ], listing_for("rent").transactions.map(&:name)
    assert_equal [ "Rent" ], listing_for("rent @sep").transactions.map(&:name)
    assert_empty listing_for("rent @oct").transactions
    assert_equal [ "Rent" ], listing_for("@sep").transactions.map(&:name)
    assert_equal [ 150_000, 1 ], [ listing_for("rent").spent, listing_for("rent").count ]
  end

  test "tokens that matched nothing leave the month as it was" do
    assert_equal 2, listing_for("#nothing @whenever").count
  end

  test "counts the rows needing a category among the others the search narrows to, whether or not it asks for them" do
    activate(connect_simplefin)
    savings = BankAccount.find_by!(external_id: "Demo Savings")
    needing = users(:one).transactions.from_bank_account(savings).needing_category.count

    assert_operator needing, :>, 0
    assert_equal [ needing, needing ], [ listing_for("in:savings", today: Date.current).needing_category_count, listing_for("in:savings ?", today: Date.current).needing_category_count ]
    assert_equal needing, listing_for("in:savings ?", today: Date.current).count
  end

  private
    def listing_for(q, today: Date.new(2026, 10, 15))
      query = Transaction::Query.parse(q, user: users(:one), today:)
      Transaction::Listing.new(users(:one).transactions, period: @month, query:, before: nil)
    end
end
