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
    rows = { "2026-09-30" => 45, "2026-09-29" => 45, "2026-09-28" => 5 }.flat_map do |date, count|
      Array.new(count) { { user_id: users(:one).id, name: "Lunch", amount_in_cents: -1_000, occurred_on: date } }
    end
    Transaction.insert_all!(rows)

    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(month: "2026-09")
      assert_select "main section li", 90
      assert_select "turbo-frame#days_2026-09-29[loading=lazy][refresh=morph][src=?]", transactions_path(month: "2026-09", before: "2026-09-29")
      assert_equal [ "95" ], css_select("dl dd").map(&:text).last(1)

      get transactions_url(month: "2026-09", before: "2026-09-29")
      assert_select "turbo-frame#days_2026-09-29 section li", 5
      assert_select "turbo-frame#days_2026-09-29 turbo-frame", 0

      get transactions_url(month: "2026-09", before: "2026-09-30")
      assert_select "turbo-frame#days_2026-09-30 section", 0
    end
  end

  test "sorts by date either way and keeps the days, their totals and the day pages" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "date", direction: "desc")
    assert_equal [ "Wed, Oct 7", "Tue, Oct 6", "Sat, Oct 3", "Fri, Oct 2", "Thu, Oct 1" ], css_select("main section h2").map(&:text)
    assert_equal [ "avocado", "Card payment", "Dentist", "Cherry", "Paycheck", "Blue Bottle" ], row_names
    assert_select "main section[aria-label='Sat, Oct 3'] [data-field=day-total]", text: "$380.00"

    get transactions_url(month: "2026-10", sort: "date", direction: "asc")
    assert_equal [ "Thu, Oct 1", "Fri, Oct 2", "Sat, Oct 3", "Tue, Oct 6", "Wed, Oct 7" ], css_select("main section h2").map(&:text)
    assert_equal [ "Blue Bottle", "Paycheck", "Dentist", "Cherry", "Card payment", "avocado" ], row_names
  end

  test "sorts by name without regard to case" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "name")
    assert_equal [ "avocado", "Blue Bottle", "Card payment", "Cherry", "Dentist", "Paycheck" ], row_names

    get transactions_url(month: "2026-10", sort: "name", direction: "desc")
    assert_equal [ "Paycheck", "Dentist", "Cherry", "Card payment", "Blue Bottle", "avocado" ], row_names
  end

  test "sorts by category and leaves the uncategorized and transfers last either way" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "category")
    assert_equal [ "Cherry", "Blue Bottle", "Dentist", "Paycheck", "avocado", "Card payment" ], row_names

    get transactions_url(month: "2026-10", sort: "category", direction: "desc")
    assert_equal [ "Paycheck", "Dentist", "Cherry", "Blue Bottle", "avocado", "Card payment" ], row_names
  end

  test "sorts by account as shown, institution first, and leaves rows the bank never saw last either way" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "account")
    assert_equal [ "Cherry", "avocado", "Dentist", "Card payment", "Paycheck", "Blue Bottle" ], row_names

    get transactions_url(month: "2026-10", sort: "account", direction: "desc")
    assert_equal [ "avocado", "Dentist", "Cherry", "Card payment", "Paycheck", "Blue Bottle" ], row_names
  end

  test "sorts by amount with the biggest outflow first, or the biggest inflow" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "amount")
    assert_equal [ "Cherry", "Dentist", "Card payment", "avocado", "Blue Bottle", "Paycheck" ], row_names

    get transactions_url(month: "2026-10", sort: "amount", direction: "desc")
    assert_equal [ "Paycheck", "Blue Bottle", "avocado", "Card payment", "Dentist", "Cherry" ], row_names
  end

  test "a sort other than the date lists one row after another and dates each row" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "name")

    assert_select "main section", 0
    assert_select "main h2", text: /Oct/, count: 0
    assert_select "li##{ActionView::RecordIdentifier.dom_id(transactions(:paycheck))} p", text: "Oct 2"
    assert_select "li##{ActionView::RecordIdentifier.dom_id(transactions(:paycheck))} span", text: "· Oct 2"
    assert_select "[data-field=spent]", text: "$397.50"
  end

  test "an unknown sort reads as the newest first" do
    add_sortable_rows

    get transactions_url(month: "2026-10", sort: "balance", direction: "asc")

    assert_response :success
    assert_equal [ "Wed, Oct 7", "Tue, Oct 6", "Sat, Oct 3", "Fri, Oct 2", "Thu, Oct 1" ], css_select("main section h2").map(&:text)
    assert_select "[role=columnheader][aria-sort=descending]", text: "Date"
  end

  test "the headers sort the list, and the one in use says which way" do
    travel_to Time.utc(2026, 10, 13, 12)

    get transactions_url

    assert_select "[role=columnheader][aria-sort=descending]", text: "Date"
    assert_select "[role=columnheader][aria-sort]", 1
    assert_select "[role=columnheader] a[href=?]", transactions_path(month: "2026-10", sort: "date", direction: "asc"), text: "Date"
    assert_select "[role=columnheader] a[href=?]", transactions_path(month: "2026-10", sort: "name"), text: "Name"
    assert_select "[role=columnheader] a[href=?]", transactions_path(month: "2026-10", sort: "amount"), text: "Amount"

    get transactions_url(sort: "name")

    assert_select "[role=columnheader][aria-sort=ascending]", text: "Name"
    assert_select "[role=columnheader] a[href=?]", transactions_path(month: "2026-10", sort: "name", direction: "desc"), text: "Name"
    assert_select "[role=columnheader] a[href=?]", transactions_path(month: "2026-10"), text: "Date"
    assert_select "[aria-hidden=true]", text: "Name", count: 0
  end

  test "a phone sorts from a menu that names the sort in use" do
    travel_to Time.utc(2026, 10, 13, 12)

    get transactions_url(sort: "amount", direction: "desc")

    assert_select "details summary", text: /Sort: Amount/
    assert_select "details a[aria-current=true][href=?]", transactions_path(month: "2026-10", sort: "amount"), text: "Amount"
    assert_select "details a[href=?]", transactions_path(month: "2026-10", sort: "name"), text: "Name"
    assert_select "details a[href=?]", transactions_path(month: "2026-10"), text: "Date"
  end

  test "the sort follows the search, its tokens, the month steps and the needs-a-category toggle" do
    add_sortable_rows

    get transactions_url(q: "#food @2026-10", sort: "name", direction: "desc")

    assert_select "form input[type=hidden][name=sort][value=name]"
    assert_select "form input[type=hidden][name=direction][value=desc]"
    assert_select "[data-field=token] a[aria-label='Remove Food'][href=?]", transactions_path(q: "@2026-10", month: "2026-10", sort: "name", direction: "desc")
    assert_select "nav[aria-label=Month] a[href=?]", transactions_path(q: "#food @2026-09", sort: "name", direction: "desc"), text: "‹ Sep"

    get transactions_url(q: ">1", month: "2026-10", sort: "name", direction: "desc")

    assert_select "a[aria-pressed=false][href*='sort=name'][href*='direction=desc']", text: /Needs a category/
  end

  test "the sort follows a search across every month" do
    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(q: "rent", sort: "amount")
    end

    assert_select "nav[aria-label='Months searched'] a[href=?]", transactions_path(q: "rent @2026-10", month: "2026-10", sort: "amount"), text: "October 2026"
  end

  test "the default sort leaves every link and field without sort params" do
    travel_to Time.utc(2026, 10, 13, 12)

    get transactions_url

    assert_select "form input[name=sort]", 0
    assert_select "form input[name=direction]", 0
    assert_select "nav[aria-label=Month] a[href*=sort]", 0
  end

  test "a long list in another sort pages by rows and keeps the sort on every page" do
    rows = Array.new(60) { |index| { user_id: users(:one).id, name: format("Row %02d", index), amount_in_cents: -1_000, occurred_on: "2026-09-#{format("%02d", index % 28 + 1)}" } }
    Transaction.insert_all!(rows)

    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(month: "2026-09", sort: "name")
      assert_equal (0..49).map { |index| format("Row %02d", index) }, row_names
      assert_select "turbo-frame#rows_2[loading=lazy][refresh=morph][src=?]", transactions_path(month: "2026-09", sort: "name", page: 2)
      assert_equal [ "60" ], css_select("dl dd").map(&:text).last(1)

      get transactions_url(month: "2026-09", sort: "name", page: 2)
      assert_select "turbo-frame#rows_2 li", 10
      assert_equal (50..59).map { |index| format("Row %02d", index) }, css_select("turbo-frame#rows_2 li [data-field=name]").map(&:text)
      assert_select "turbo-frame#rows_2 turbo-frame", 0

      get transactions_url(month: "2026-09", sort: "name", direction: "desc", page: 2)
      assert_equal (0..9).map { |index| format("Row %02d", index) }.reverse, css_select("turbo-frame#rows_2 li [data-field=name]").map(&:text)

      get transactions_url(month: "2026-09", sort: "name", page: 3)
      assert_select "turbo-frame#rows_3 li", 0
    end
  end

  test "an oldest-first list loads its later days as it scrolls" do
    rows = { "2026-09-28" => 5, "2026-09-29" => 45, "2026-09-30" => 45 }.flat_map do |date, count|
      Array.new(count) { { user_id: users(:one).id, name: "Lunch", amount_in_cents: -1_000, occurred_on: date } }
    end
    Transaction.insert_all!(rows)

    travel_to Time.utc(2026, 10, 13, 12) do
      get transactions_url(month: "2026-09", sort: "date", direction: "asc")
      assert_select "main section li", 50
      assert_equal [ "Mon, Sep 28", "Tue, Sep 29" ], css_select("main section h2").map(&:text)
      assert_select "turbo-frame#days_2026-09-29[loading=lazy][src=?]", transactions_path(month: "2026-09", sort: "date", direction: "asc", before: "2026-09-29")

      get transactions_url(month: "2026-09", sort: "date", direction: "asc", before: "2026-09-29")
      assert_equal [ "Wed, Sep 30" ], css_select("turbo-frame#days_2026-09-29 section h2").map(&:text)
      assert_select "turbo-frame#days_2026-09-29 turbo-frame", 0
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

  test "the sheet is the edit form with the category, Delete, and Save" do
    @transaction.update!(note: "With Sam")

    get edit_transaction_url(@transaction)

    assert_response :success
    assert_select "turbo-frame#sheet h2", text: "Blue Bottle"
    assert_select "turbo-frame#sheet p", text: "Thu, Oct 1"
    assert_select "turbo-frame#sheet [data-category-picker-size-value=large] button[data-category-picker-url-param=?]",
      transaction_categorization_path(@transaction), text: "Food"
    assert_select "turbo-frame#sheet form[action=?]", transaction_path(@transaction) do
      assert_select "input[name='transaction[name]'][value='Blue Bottle']"
      assert_select "input[name='transaction[amount]'][value='5.50']"
      assert_select "input[type=date][name='transaction[occurred_on]'][value='2026-10-01']"
    end
    assert_select "turbo-frame#sheet input[name='transaction[note]'][value='With Sam']"
    assert_select "turbo-frame#sheet form[action=?] button", transaction_path(@transaction), text: "Delete"
    assert_select "turbo-frame#sheet button[form=sheet_edit]", text: "Save"
  end

  test "the sheet shows money in with a plus" do
    get edit_transaction_url(transactions(:paycheck))

    assert_select "turbo-frame#sheet input[name='transaction[amount]'][value='+2000.00']"
  end

  test "each row offers Edit, which opens the sheet" do
    get transactions_url

    assert_select "li#transaction_#{@transaction.id} [role=group] a[aria-label=Edit][data-turbo-frame=sheet][href=?]", edit_transaction_path(@transaction)
  end

  test "edits the name, amount, and date, and forgets the shorthand" do
    patch transaction_url(@transaction), params: { transaction: { name: "Philz", amount: "$6.25", occurred_on: "2026-10-02", note: "" } }

    assert_response :see_other
    @transaction.reload
    assert_equal [ "Philz", -625, Date.new(2026, 10, 2), nil ], [ @transaction.name, @transaction.amount_in_cents, @transaction.occurred_on, @transaction.shorthand ]
  end

  test "a plus amount is money in" do
    patch transaction_url(@transaction), params: { transaction: { name: "Refund", amount: "+1,200", occurred_on: "2026-10-01", note: "" } }

    assert_equal 120_000, @transaction.reload.amount_in_cents
  end

  test "a note-only edit keeps the shorthand" do
    patch transaction_url(@transaction), params: { transaction: { name: "Blue Bottle", amount: "5.50", occurred_on: "2026-10-01", note: "With Sam" } }

    @transaction.reload
    assert_equal [ "With Sam", "Blue Bottle 5.50" ], [ @transaction.note, @transaction.shorthand ]
  end

  test "an edit that fails keeps the sheet open with what was typed and changes nothing" do
    [ [ { name: "", amount: "5", occurred_on: "2026-10-01" }, "Type a name, like coffee" ],
      [ { name: "Philz", amount: "abc", occurred_on: "2026-10-01" }, "Type an amount, like 5.50" ],
      [ { name: "Philz", amount: "0", occurred_on: "2026-10-01" }, "Type an amount, like 5.50" ],
      [ { name: "Philz", amount: "5", occurred_on: "" }, "Pick a date" ] ].each do |fields, message|
      patch transaction_url(@transaction), params: { transaction: fields.merge(note: "kept") }

      assert_response :unprocessable_entity
      assert_select "turbo-stream[action=replace][target=sheet]"
      assert_includes response.body, message
      assert_includes response.body, "kept"
      assert_equal [ "Blue Bottle", -550, Date.new(2026, 10, 1), nil ], @transaction.reload.then { [ _1.name, _1.amount_in_cents, _1.occurred_on, _1.note ] }
    end
  end

  test "another user's transaction cannot be edited" do
    sign_in_as(users(:two))

    patch transaction_url(@transaction), params: { transaction: { name: "Mine", amount: "1", occurred_on: "2026-10-01", note: "" } }

    assert_response :not_found
    assert_equal "Blue Bottle", @transaction.reload.name
  end

  test "a bank-added row can be edited and its bank name is untouched" do
    activate(connect_simplefin)
    transaction = Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: -13_550).transaction_id)
    bank_transaction = transaction.bank_transaction
    key = bank_transaction.name_key

    patch transaction_url(transaction), params: { transaction: { name: "Costco run", amount: "140", occurred_on: transaction.occurred_on.iso8601, note: "" } }

    assert_response :see_other
    assert_equal [ "Costco run", -14_000 ], [ transaction.reload.name, transaction.amount_in_cents ]
    assert_equal key, bank_transaction.reload.name_key
    assert_includes users(:one).transactions_named(key), transaction
  end

  test "a renamed bank row still takes the rule made from its bank name" do
    activate(connect_simplefin)
    user = users(:one)
    transaction = Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: -13_550).transaction_id)
    bank_name = transaction.bank_transaction_name

    patch transaction_url(transaction), params: { transaction: { name: "Costco run", amount: "135.50", occurred_on: transaction.occurred_on.iso8601, note: "" } }
    user.remember(bank_name, Transaction::Categorization.new(category: categories(:food)))

    assert_equal categories(:food), transaction.reload.category
    assert transaction.offers_rule? == false
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

  test "adds a row in an income category as money in" do
    post transactions_url, params: { shorthand: "work payment 3491.60 #income", idempotency_key: "key-income" }

    assert_equal [ 349160, categories(:income) ], Transaction.order(:id).last.then { |transaction| [ transaction.amount_in_cents, transaction.category ] }
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

  private
    def row_names
      css_select("main li [data-field=name]").map(&:text)
    end

    def add_sortable_rows
      travel_to Time.utc(2026, 10, 13, 12)
      transactions(:paycheck).update!(occurred_on: "2026-10-02")
      user = users(:one)
      health = user.categories.create!(name: "Health")
      access = connect_simplefin(user)
      amex = access.bank_accounts.create!(external_id: "amex", name: "Amex Gold", institution: "Zeta Bank", currency: "USD")
      chase = access.bank_accounts.create!(external_id: "chase", name: "Chase Checking", currency: "USD")
      sync = access.syncs.create!

      [ [ "avocado", "2026-10-07", -1_200, nil, amex ], [ "Cherry", "2026-10-03", -30_000, categories(:food), chase ],
        [ "Dentist", "2026-10-03", -8_000, health, amex ], [ "Card payment", "2026-10-06", -5_000, nil, nil ] ].each do |name, date, cents, category, account|
        transaction = user.transactions.create!(name:, occurred_on: date, amount_in_cents: cents, category:, transfer: name == "Card payment")
        account&.bank_transactions&.create!(simplefin_sync: sync, transaction_id: transaction.id, external_id: SecureRandom.hex(4), amount_in_cents: cents,
          occurred_on: date, description: name, name_key: name.downcase)
      end
    end
end
