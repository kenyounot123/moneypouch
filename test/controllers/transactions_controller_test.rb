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
    assert_select "main section li [data-field=name]", text: "Rent", count: 0
  end

  test "shows the day total even when the day has one row" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Tea", amount_in_cents: -300, occurred_on: "2026-10-02")

      get transactions_url
    end

    assert_select "section[aria-label='Fri, Oct 2'] [data-field=day-total]", text: "$3.00", count: 1
  end

  test "a day of only transfers shows no money moved" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Card payment", amount_in_cents: -50_000, occurred_on: "2026-10-02", transfer: true)

      get transactions_url
    end

    assert_select "section[aria-label='Fri, Oct 2'] [data-field=day-total]", text: "$0.00", count: 1
  end

  test "shows the requested month only" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-09-30")

      get transactions_url(month: "2026-09")
    end

    assert_select "main section li", 1
    assert_select "main section li [data-field=name]", text: "Rent"
    assert_select "[data-field=spent]", text: "$1,500.00"
  end

  test "totals what was spent, earned, and kept for the month" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "p", text: "Spent in October"
    assert_select "[data-field=spent]", text: "$5.50"
    assert_equal [ "$2,000.00", "+$1,994.50", "2" ], css_select("dl dd").map(&:text)
    assert_select "p", text: "Income $2,000.00 · Net +$1,994.50 · 2 transactions"
    assert_select "main section [data-field=day-total]", text: "+$1,994.50", count: 1
  end

  test "searches names and notes, and the totals follow the search" do
    transactions(:paycheck).update!(note: "October pay")

    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: "BOTTLE")
      assert_select "main section li", 1
      assert_select "li#transaction_#{@transaction.id}"
      assert_select "[data-field=spent]", text: "$5.50"

      get transactions_url(q: "october")
      assert_select "main section li", 1
      assert_select "li#transaction_#{transactions(:paycheck).id}"
      assert_select "[data-field=token][data-kind=text][data-raw=october]", text: /october/
    end
  end

  test "narrows to one category or to several, and a token that matches nothing is flagged and ignored" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: "#food")
      assert_select "main section li", 1
      assert_select "li#transaction_#{@transaction.id}"
      assert_select "[data-field=token][data-kind=category]", text: /Food/

      get transactions_url(q: "#income")
      assert_select "main section li", 1
      assert_select "li#transaction_#{transactions(:paycheck).id}"

      get transactions_url(q: "#food #income")
      assert_select "main section li", 2

      get transactions_url(q: "#nothing")
      assert_select "main section li", 2
      assert_select "[data-field=token][data-raw='#nothing'][title='No category matches “nothing”.']"
    end
  end

  test "another user's category is not a token" do
    users(:two).categories.create!(name: "Secret")

    get transactions_url(q: "#secret")

    assert_select "[data-field=token][title]"
  end

  test "narrows by amount, account and money direction" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: ">100")
      assert_select "main section li", 1
      assert_select "li#transaction_#{transactions(:paycheck).id}"

      get transactions_url(q: "<10")
      assert_select "li#transaction_#{@transaction.id}"
      assert_select "main section li", 1

      get transactions_url(q: "+")
      assert_select "li#transaction_#{transactions(:paycheck).id}"
      assert_select "main section li", 1

      get transactions_url(q: "in:typed")
      assert_select "main section li", 2
    end
  end

  test "a search looks through every month, and the header, month steps and scope toggle say so" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-08-30")

      get transactions_url(q: "rent")

      assert_select "main section li [data-field=name]", text: "Rent"
      assert_select "p", text: "Spent across matches"
      assert_select "[data-field=spent]", text: "$1,500.00"
      assert_select "nav[aria-label=Month]", 0
      assert_select "nav[aria-label='Months searched'] [aria-current]", text: "All months"
      assert_select "nav[aria-label='Months searched'] a[href=?]", transactions_path(q: "rent @2026-10", month: "2026-10"), text: "October 2026"
    end
  end

  test "a month token pins the search to that month, and the month steps keep the rest of it" do
    travel_to Time.utc(2026, 10, 13, 12) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-08-30")
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -150_000, occurred_on: "2026-09-30")

      get transactions_url(q: "rent @aug")

      assert_select "main section li", 1
      assert_select "section[aria-label='Sun, Aug 30']"
      assert_select "p", text: "Spent in August"
      assert_select "nav[aria-label=Month] [aria-current]", text: "August 2026"
      assert_select "nav[aria-label=Month] a[href=?]", transactions_path(q: "rent @2026-07"), text: "‹ Jul"
      assert_select "nav[aria-label=Month] a[href=?]", transactions_path(q: "rent @2026-09"), text: "Sep ›"
      assert_select "a[href=?]", transactions_path(q: "rent", month: "2026-08"), text: "All months"
    end
  end

  test "a date range token narrows without a month, and its toggle offers every month or this one" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: "@30d")

      assert_select "main section li", 2
      assert_select "p", text: "Spent across matches"
      assert_select "nav[aria-label='Months searched'] a[href=?]", transactions_path(month: "2026-10"), text: "All months"
    end
  end

  test "says so when nothing matches, and offers every month when a month token was in the way" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: "nothing like this")
      assert_select "main p", text: "No transactions match."
      assert_select "main a", text: "Search all months", count: 0

      get transactions_url(q: "tea @2026-08")
      assert_select "main p", text: /No transactions match\./
      assert_select "main a[href=?]", transactions_path(q: "tea", month: "2026-08"), text: "Search all months"

      get transactions_url(month: "2026-08")
      assert_select "main p", text: "Nothing in August."
      assert_select "main section", 0
    end
  end

  test "each token can be removed, and the page drops the old dropdowns" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: "#food >2", month: "2026-10")
    end

    assert_select "[data-field=token][data-kind=category] a[aria-label='Remove Food'][href=?]", transactions_path(q: ">2", month: "2026-10")
    assert_select "[data-field=token][data-kind=amount] a[aria-label='Remove Over $2'][href=?]", transactions_path(q: "#food", month: "2026-10")
    assert_select "select", 0
    assert_select "label", text: "Filters", count: 0
  end

  test "the search field carries the categories and accounts for its suggestions, and fetches merchants on its own" do
    get transactions_url

    assert_select "main[data-controller=search][data-search-suggestions-url-value=?]", transactions_suggestions_path
    assert_select "main[data-search-categories-value=?]", [ { name: "Food", token: "#food", count: 1 }, { name: "Income", token: "#income", count: 1 } ].to_json
    assert_select "main[data-search-accounts-value=?]", "[]"
    assert_select "input[role=combobox][aria-controls=search-popup]"
    assert_select "#search-popup[role=listbox][hidden]"
  end

  test "a row's merchant pivots the search to itself, and its category stays the picker" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "li#transaction_#{@transaction.id} [data-field=name] [data-action='click->search#pivot'][data-search-token-param=?][title=?]", %("Blue Bottle"), "Show all Blue Bottle"
    assert_select "li#transaction_#{@transaction.id} button[data-action='category-picker#open']", text: "Food"
    assert_select "li#transaction_#{@transaction.id} button[data-action*='search#pivot']", 0
  end

  test "steps to the month before and offers the next one only for past months" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
      assert_select "nav[aria-label=Month] a", text: "‹ Sep"
      assert_select "nav[aria-label=Month] [aria-current]", text: "October 2026"
      assert_select "nav[aria-label=Month] a", text: "Nov ›", count: 0

      get transactions_url(month: "2026-09", q: "#nothing")
      assert_select "nav[aria-label=Month] a[href=?]", transactions_path(q: "#nothing", month: "2026-10"), text: "Oct ›"
    end
  end

  test "clamps a future month to this one" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(month: "2027-02")
    end

    assert_select "nav[aria-label=Month] [aria-current]", text: "October 2026"
    assert_select "main section li", 2
  end

  test "offers a way back to the top" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "button[aria-label='Back to top'][data-controller=back-to-top]"
  end

  test "a busy month shows its newest days first and loads the rest as the list scrolls" do
    rows = { "2026-09-30" => 90, "2026-09-29" => 90, "2026-09-28" => 5 }.flat_map do |date, count|
      Array.new(count) { { user_id: users(:one).id, name: "Lunch", amount_in_cents: -1_000, occurred_on: date } }
    end
    Transaction.insert_all!(rows)

    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(month: "2026-09")
      assert_select "main section li", 180
      assert_select "turbo-frame#days_2026-09-29[loading=lazy][refresh=morph][src=?]", transactions_path(month: "2026-09", before: "2026-09-29")
      assert_equal [ "185" ], css_select("dl dd").map(&:text).last(1)

      get transactions_url(month: "2026-09", before: "2026-09-29")
      assert_select "turbo-frame#days_2026-09-29 section li", 5
      assert_select "turbo-frame#days_2026-09-29 turbo-frame", 0

      get transactions_url(month: "2026-09", before: "2026-09-30")
      assert_select "turbo-frame#days_2026-09-30 section", 0
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

    assert_select "[data-controller=category-picker][data-category-picker-categories-value=?]", [ [ "Food", false ], [ "Income", true ] ].to_json
    assert_select "li##{ActionView::RecordIdentifier.dom_id(transactions(:paycheck))} button[data-category-picker-url-param=?]",
      transaction_categorization_path(transactions(:paycheck)), text: "Income"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(transactions(:paycheck))} button[data-category-picker-category-param=Income][data-category-picker-money-in-param=true]"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(@transaction)} button[data-category-picker-category-param=Food][data-category-picker-money-in-param=false]", text: "Food"
  end

  test "each row deletes from the ledger and opens its sheet on a phone" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url
    end

    assert_select "li#transaction_#{@transaction.id} form[action=?] button[aria-label=Delete][title=Delete] .icon--delete", transaction_path(@transaction)
    assert_select "li#transaction_#{@transaction.id} a[data-turbo-frame=sheet][href=?]", edit_transaction_path(@transaction)
    assert_select "dialog[data-controller=sheet] turbo-frame#sheet"
  end

  test "the sheet holds the category, the note, and Delete" do
    @transaction.update!(note: "With Sam")

    get edit_transaction_url(@transaction)

    assert_response :success
    assert_select "turbo-frame#sheet h2", text: "Blue Bottle"
    assert_select "turbo-frame#sheet p", text: "Thu, Oct 1"
    assert_select "turbo-frame#sheet [data-category-picker-size-value=large] button[data-category-picker-url-param=?]",
      transaction_categorization_path(@transaction), text: "Food"
    assert_select "turbo-frame#sheet form[action=?] input[name='transaction[note]'][value='With Sam']", transaction_note_path(@transaction)
    assert_select "turbo-frame#sheet form[action=?] button", transaction_path(@transaction), text: "Delete"
    assert_select "turbo-frame#sheet button[form=sheet_note]", text: "Done"
  end

  test "another user's sheet is not found" do
    sign_in_as(users(:two))

    get edit_transaction_url(@transaction)

    assert_response :not_found
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
