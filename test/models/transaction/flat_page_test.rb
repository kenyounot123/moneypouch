require "test_helper"

class Transaction::FlatPageTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Transaction.insert_all!(Array.new(120) { |index| { user_id: @user.id, name: format("Row %03d", index), amount_in_cents: -100, occurred_on: "2025-03-15" } })
    @transactions = @user.transactions.where("name LIKE ?", "Row %").order(:name)
  end

  test "cuts the list at 50 rows and points at the next page" do
    page = page_for(1)

    assert_equal (0..49).map { |index| format("Row %03d", index) }, page.transactions.pluck(:name)
    assert_equal 2, page.next_number
    assert_equal({ page: 2 }, page.next_params)
    assert_equal [ "rows", "rows_2" ], [ page.frame_id, page.next_frame_id ]
  end

  test "a later page carries on where the last one stopped, and the last page has no next" do
    assert_equal (50..99).map { |index| format("Row %03d", index) }, page_for(2).transactions.pluck(:name)
    assert_equal "rows_2", page_for(2).frame_id

    last = page_for(3)

    assert_equal 20, last.transactions.count
    assert_nil last.next_number
    assert_nil last.next_params
  end

  test "a page past the end shows nothing" do
    assert_empty page_for(9).transactions
  end

  test "a list that fits on one page has no next page" do
    page = Transaction::FlatPage.new(@transactions, count: Transaction::Page::ROWS, number: 1)

    assert_nil page.next_number
  end

  private
    def page_for(number)
      Transaction::FlatPage.new(@transactions, count: @transactions.count, number:)
    end
end
