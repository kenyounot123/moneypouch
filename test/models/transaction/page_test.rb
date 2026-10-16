require "test_helper"

class Transaction::PageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    add_rows "2025-03-30" => 40, "2025-03-29" => 40, "2025-03-28" => 40, "2025-03-27" => 40, "2025-03-26" => 10
    @month = @user.transactions.occurred_in(Date.new(2025, 3, 1).all_month)
  end

  test "fills a page with whole days until it holds at least 100 rows" do
    page = Transaction::Page.new(@month, before: nil)

    assert_equal 120, page.transactions.count
    assert_equal [ Date.new(2025, 3, 28), Date.new(2025, 3, 30) ], page.transactions.pluck(:occurred_on).minmax
    assert_equal Date.new(2025, 3, 28), page.next_before
  end

  test "the next page starts the day before the last one" do
    page = Transaction::Page.new(@month, before: Date.new(2025, 3, 28))

    assert_equal 50, page.transactions.count
    assert_nil page.next_before
  end

  test "a month that fits on one page has no next page" do
    page = Transaction::Page.new(@user.transactions.occurred_in(Date.new(2025, 3, 26)..Date.new(2025, 3, 27)), before: nil)

    assert_equal 50, page.transactions.count
    assert_nil page.next_before
  end

  test "a page that no longer starts where the one before ends shows nothing" do
    add_rows "2025-03-30" => 100

    page = Transaction::Page.new(@month, before: Date.new(2025, 3, 28))

    assert_empty page.transactions
    assert_nil page.next_before
  end

  private
    def add_rows(counts)
      rows = counts.flat_map do |date, count|
        Array.new(count) { |index| { user_id: @user.id, name: "Row #{index}", amount_in_cents: -100, occurred_on: date } }
      end

      Transaction.insert_all!(rows)
    end
end
