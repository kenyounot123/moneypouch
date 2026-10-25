require "test_helper"

class Transaction::PageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    add_rows "2025-03-30" => 20, "2025-03-29" => 20, "2025-03-28" => 20, "2025-03-27" => 20, "2025-03-26" => 5
    @month = @user.transactions.occurred_in(Date.new(2025, 3, 1).all_month)
  end

  test "fills a page with whole days until it holds at least 50 rows" do
    page = page_for(@month, before: nil)

    assert_equal 60, page.transactions.count
    assert_equal [ Date.new(2025, 3, 28), Date.new(2025, 3, 30) ], page.transactions.pluck(:occurred_on).minmax
    assert_equal Date.new(2025, 3, 28), page.next_before
  end

  test "the next page starts the day before the last one" do
    page = page_for(@month, before: Date.new(2025, 3, 28))

    assert_equal 25, page.transactions.count
    assert_nil page.next_before
  end

  test "a month that fits on one page has no next page" do
    page = page_for(@user.transactions.occurred_in(Date.new(2025, 3, 26)..Date.new(2025, 3, 27)), before: nil)

    assert_equal 25, page.transactions.count
    assert_nil page.next_before
  end

  test "a page that no longer starts where the one before ends shows nothing" do
    add_rows "2025-03-30" => 50

    page = page_for(@month, before: Date.new(2025, 3, 28))

    assert_empty page.transactions
    assert_nil page.next_before
  end

  test "an oldest-first list fills a page with whole days from the oldest and then continues after the last one" do
    page = page_for(@month, before: nil, order: :asc)

    assert_equal 65, page.transactions.count
    assert_equal [ Date.new(2025, 3, 26), Date.new(2025, 3, 29) ], page.transactions.pluck(:occurred_on).minmax
    assert_equal Date.new(2025, 3, 29), page.next_before

    later = page_for(@month, before: Date.new(2025, 3, 29), order: :asc)

    assert_equal 20, later.transactions.count
    assert_equal [ Date.new(2025, 3, 30), Date.new(2025, 3, 30) ], later.transactions.pluck(:occurred_on).minmax
    assert_nil later.next_before
  end

  private
    def page_for(transactions, before:, order: :desc)
      Transaction::Page.new(transactions, counts: transactions.group(:occurred_on).order(occurred_on: order).count, before:)
    end

    def add_rows(counts)
      rows = counts.flat_map do |date, count|
        Array.new(count) { |index| { user_id: @user.id, name: "Row #{index}", amount_in_cents: -100, occurred_on: date } }
      end

      Transaction.insert_all!(rows)
    end
end
