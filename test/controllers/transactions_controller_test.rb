require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @transaction = transactions(:coffee)
    sign_in_as(users(:one))
  end

  test "lists this month's rows by day, newest first" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02")
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-09-30")

      get transactions_url
    end

    assert_response :success
    assert_equal [ "Fri, Oct 2", "Thu, Oct 1" ], css_select("main section h2").map(&:text)
    assert_select "main section li p.font-medium", text: "Rent", count: 0
  end

  test "shows the requested month only" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-09-30")

      get transactions_url(month: "2026-09")
    end

    assert_select "main section li", 1
    assert_select "main section li div.h-10 p.font-medium", text: "Rent"
    assert_select ".text-display", text: "$1,500.00"
  end

  test "totals what was spent, earned, and kept for the month" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "p", text: "Spent in October"
    assert_select ".text-display", text: "$5.50"
    assert_equal [ "$2,000.00", "$1,994.50", "2" ], css_select("dl dd").map(&:text)
    assert_select "p", text: "Income $2,000.00 · Net $1,994.50 · 2 transactions"
    assert_select "main section p.font-mono", text: "+$1,994.50", count: 2
  end

  test "searches names and notes, and the totals follow the search" do
    transactions(:paycheck).update!(note: "October pay")

    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(query: "BOTTLE")
      assert_select "main section li", 1
      assert_select "li#transaction_#{@transaction.id}"
      assert_select ".text-display", text: "$5.50"

      get transactions_url(query: "october")
      assert_select "main section li", 1
      assert_select "li#transaction_#{transactions(:paycheck).id}"
      assert_select "input#query[value=october]"
    end
  end

  test "narrows to one category or to rows with none" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(category: categories(:food).id)
      assert_select "main section li", 1
      assert_select "li#transaction_#{@transaction.id}"

      get transactions_url(category: "none")
      assert_select "main section li", 1
      assert_select "li#transaction_#{transactions(:paycheck).id}"
    end
  end

  test "says so when nothing matches, and when the month is empty" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(query: "nothing like this")
      assert_select "main p", text: "No transactions match."

      get transactions_url(month: "2026-08")
      assert_select "main p", text: "Nothing in August."
      assert_select "main section", 0
    end
  end

  test "steps to the month before and offers the next one only for past months" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
      assert_select "nav[aria-label=Month] a", text: "‹ Sep"
      assert_select "nav[aria-label=Month] [aria-current]", text: "October 2026"
      assert_select "nav[aria-label=Month] a", text: "Nov ›", count: 0

      get transactions_url(month: "2026-09", query: "tea")
      assert_select "nav[aria-label=Month] a[href=?]", transactions_path(query: "tea", month: "2026-10"), text: "Oct ›"
    end
  end

  test "clamps a future month to this one" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(month: "2027-02")
    end

    assert_select "nav[aria-label=Month] [aria-current]", text: "October 2026"
    assert_select "main section li", 2
  end

  test "ends the month with its count and a link to the month before" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-09-30")

      get transactions_url
      assert_select "p", text: "That's all of October"
      assert_select "p", text: "2 transactions · $5.50 spent"
      assert_select "a[href=?]", transactions_path(month: "2026-09"), text: /September\s+1 transaction/

      get transactions_url(month: "2026-09")
      assert_select "a", text: /August/, count: 0
    end
  end

  test "marks Transactions as the current page in the sidebar" do
    get transactions_url

    assert_select "#sidebar a[aria-current=page][href=?]", transactions_path, text: "Transactions"
  end

  test "each row's category opens the picker for that transaction" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "[data-controller=category-picker][data-category-picker-categories-value=?]", [ "Food" ].to_json
    assert_select "li##{ActionView::RecordIdentifier.dom_id(transactions(:paycheck))} button[data-category-picker-url-param=?]",
      transaction_categorization_path(transactions(:paycheck)), text: "Uncategorized"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(@transaction)} button[data-category-picker-category-param=Food]", text: "Food"
  end

  test "each row deletes from the ledger" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "li#transaction_#{@transaction.id} form[action=?] button", transaction_path(@transaction), text: "Delete"
  end

  test "should update transaction" do
    patch transaction_url(@transaction), params: { transaction: { amount_in_cents: "2999" } }
    assert_redirected_to transactions_url
  end

  test "adds the typed shorthand and redirects back" do
    travel_to Time.utc(2026, 9, 27, 12) do
      assert_difference("Transaction.count", 1) do
        post transactions_url, params: { shorthand: "coffee 5.50", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => root_url }
      end
    end

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert_equal({ "name" => "coffee", "amount_in_cents" => -550, "shorthand" => "coffee 5.50", "occurred_on" => Date.new(2026, 9, 27), "user_id" => users(:one).id },
      Transaction.order(:id).last.slice(:name, :amount_in_cents, :shorthand, :occurred_on, :user_id))
  end

  test "adds one row for a repeated idempotency key" do
    assert_difference("Transaction.count", 1) do
      3.times { post transactions_url, params: { shorthand: "coffee 5.50", idempotency_key: "key-1" } }
    end
  end

  test "saves a new category with the row" do
    assert_difference("Category.count", 1) do
      post transactions_url, params: { shorthand: "lunch 12 #brandnew", idempotency_key: "key-2" }
    end

    assert_equal "brandnew", Transaction.order(:id).last.category.name
  end

  test "keeps invalid shorthand, shakes the voucher, and saves nothing" do
    assert_no_difference("Transaction.count") do
      post transactions_url, params: { shorthand: "coffee", idempotency_key: "key-3" }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_select "turbo-stream[action=replace][target=voucher] .animate-shake", text: /Type an amount, like 5.50/
  end

  test "undo discards the row, keeps the count, and returns its shorthand" do
    assert_no_difference("Transaction.count") do
      delete transaction_url(@transaction), headers: { "HTTP_REFERER" => root_url }
    end

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert @transaction.reload.discarded_at
    assert_equal "Blue Bottle 5.50", flash[:shorthand]
  end
end
