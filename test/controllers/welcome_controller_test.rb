require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "lists the latest kept rows in Recent with this month's count" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Old lunch", amount_in_cents: -1200, occurred_on: "2026-09-30")
      transactions(:paycheck).discard

      get root_url
    end

    assert_equal [ "Blue Bottle", "Old lunch" ], css_select("ul li p.font-medium").map(&:text)
    assert_select "p", text: "1 this month"
  end

  test "says Recent is empty when the user has no kept rows" do
    users(:one).transactions.each(&:discard)

    get root_url

    assert_select "ul li", text: "No transactions yet. Type one above.", count: 1
    assert_select "p", text: "0 this month"
  end

  test "links the total count and first month under Recent" do
    get root_url

    assert_select "a[href='#{transactions_path}']", text: "2 transactions since Oct 2026"
  end

  test "has no count link when the user has no kept rows" do
    users(:one).transactions.each(&:discard)

    get root_url

    assert_select "a[href='#{transactions_path}']", count: 0
  end

  test "shows the month's spending by category and day" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -165_000, occurred_on: "2026-10-01")
      users(:one).transactions.create!(name: "Last month", amount_in_cents: -1_000, occurred_on: "2026-09-02")

      get root_url
    end

    assert_select "p", text: "Spent in October"
    assert_select "p", text: "$1,655.50"
    assert_select "p", text: "Day 15 of 31"
    assert_select "p", text: "↑ $1,646 (16,455%) vs. Sep 1–15"
    assert_select "p", text: "Oct 1–31"
    assert_select "p", text: "Food"
    assert_select "p", text: "Uncategorized"
    assert_select "p", text: "Oct 1 Rent · $1,650"
  end

  test "shows the year by month" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(period: "year")
    end

    assert_select "p", text: "Spent in 2026"
    assert_select "p", text: "Monthly"
    assert_select "[title='October · $5.50']"
  end

  test "falls back to the month for an unknown period" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(period: "decade")
    end

    assert_select "p", text: "Spent in October"
  end

  test "says nothing was spent when the week has no spending" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(period: "week")
    end

    assert_select "p", text: "Spent this week"
    assert_select "p", text: "Nothing spent this week."
  end

  test "links each period and marks the current one" do
    get root_url(period: "week")

    assert_select "turbo-frame#spending[data-turbo-action=advance] nav[aria-label=Period] a", count: 3
    assert_select "nav[aria-label=Period] a[href='#{root_path(period: "year")}']", text: "Year"
    assert_select "nav[aria-label=Period] a[aria-current=true]", text: "Week", count: 1
  end

  test "counts Recent over the period" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Spring", amount_in_cents: -100, occurred_on: "2026-04-02")

      get root_url(period: "year")
    end

    assert_select "p", text: "3 in 2026"
  end

  test "keeps the period after an add" do
    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => root_url(period: "week") }

    assert_redirected_to root_url(period: "week")
  end

  test "opens the transactions list outside the frame" do
    get root_url

    assert_select "a[href='#{transactions_path}'][data-turbo-frame=_top]"
  end

  test "subscribes to the user's transaction refreshes" do
    get root_url

    assert_select "turbo-cable-stream-source[signed-stream-name=?]", Turbo::StreamsChannel.signed_stream_name([ users(:one), :transactions ])
  end

  test "marks Overview as the current sidebar page" do
    get root_url

    assert_select "aside a[aria-current=page]", text: "Overview", count: 1
  end

  test "renders the sidebar collapsed when the cookie says so" do
    cookies[:sidebar] = "collapsed"

    get root_url

    assert_select "html[data-sidebar=collapsed]"
    assert_select "button[aria-label='Toggle sidebar'][aria-expanded=false][aria-controls=sidebar]"
  end

  test "renders the sidebar expanded without the cookie" do
    get root_url

    assert_select "html[data-sidebar=expanded]"
    assert_select "button[aria-label='Toggle sidebar'][aria-expanded=true]"
  end

  test "renders the sidebar expanded for an unknown cookie value" do
    cookies[:sidebar] = "wide"

    get root_url

    assert_select "html[data-sidebar=expanded]"
  end

  test "marks the added row, shows the toast, and empties the field" do
    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => root_url }
    follow_redirect!

    added = Transaction.order(:id).last
    assert_select "##{ActionView::RecordIdentifier.dom_id(added)} .bg-highlight"
    assert_select "#toast_transaction_#{added.id}", text: /Added\s+tea\s+\$3.00\s+Undo\s+Ctrl Z/
    assert_select "input[name=shorthand][value='']"
  end

  test "names the Mac shortcut for a Mac browser" do
    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }
    get root_url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/130.0" }

    assert_select "[data-palette-target=undo]", text: /⌘Z/
  end

  test "puts an undone shorthand back in the field" do
    delete transaction_url(transactions(:coffee)), headers: { "HTTP_REFERER" => root_url }
    follow_redirect!

    assert_select "input[name=shorthand][value=?]", "Blue Bottle 5.50"
    assert_select "turbo-frame#voucher", text: /Blue Bottle/
  end

  test "gives the bar the user's category names in name order" do
    users(:one).categories.create!(name: "groceries")
    users(:one).categories.create!(name: "Bills")
    users(:two).categories.create!(name: "Secret")

    get root_url

    assert_select "[data-composer-categories-value=?]", '["Bills","Food","groceries"]'
  end
end
