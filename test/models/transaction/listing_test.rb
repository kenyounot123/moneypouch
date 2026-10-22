require "test_helper"

class Transaction::ListingTest < ActiveSupport::TestCase
  setup do
    @month = Period.month("2026-10", today: Date.new(2026, 10, 15))
  end

  test "totals the month's transactions" do
    listing = listing_for({})

    assert_equal [ 2, 550, 200_000, 199_450 ], [ listing.count, listing.spent, listing.income, listing.net ]
    assert_equal({ Date.new(2026, 10, 1) => 199_450 }, listing.day_totals)
  end

  test "narrows by query and category" do
    assert_equal [ "Blue Bottle" ], listing_for(query: "bottle").transactions.map(&:name)
    assert_equal [ "Paycheck" ], listing_for(category: categories(:income).id.to_s).transactions.map(&:name)
    assert_equal 0, listing_for(category: "none").count
  end

  test "typed-in rows are every row without a bank" do
    assert_equal 2, listing_for(account: "typed").count
  end

  test "another user's category is not found" do
    assert_raises(ActiveRecord::RecordNotFound) { listing_for(category: categories(:income_two).id.to_s).count }
  end

  private
    def listing_for(filters)
      Transaction::Listing.new(users(:one), month: @month, filters:, before: nil)
    end
end
