require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "lists the latest kept rows in Recent" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Old lunch", amount_in_cents: -1200, occurred_on: "2026-09-30")
      transactions(:paycheck).discard

      get root_url
    end

    assert_equal [ "Blue Bottle", "Old lunch" ], css_select("ul li p.font-medium").map(&:text)
  end

  test "an empty Recent offers to type, import a file, or connect a bank, side by side" do
    users(:one).transactions.each(&:discard)

    get root_url

    assert_equal [ "No transactions yet.", "By hand", "From a file", "From your bank" ], css_select("main ul li").map { |row| row.at_css("p")&.text || row.text }
    assert_select "main ul li button[aria-haspopup=dialog][onclick=?]", "document.getElementById('palette').showModal()", text: /Add/
    assert_select "main ul li a[href=?][data-turbo-frame=_top]", new_import_path, text: "Import"
    assert_select "main ul li a[href=?][data-turbo-frame=_top]", new_simplefin_access_path, text: "Connect"
  end

  test "Recent with rows offers no ways to start" do
    get root_url

    assert_select "main ul li", text: /From a file/, count: 0
  end

  test "links Show all from the Recent heading to the full list" do
    get root_url

    assert_select "main a[href='#{transactions_path}'][data-turbo-frame=_top]", text: "Show all", count: 1
    assert_select "main a", text: /transactions since/, count: 0
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
    assert_select "div.h-2\\.5.bg-data", 15
    assert_select "div.h-2\\.5.bg-highlight", 0
    assert_select "p", text: "Oct 1–31"
    assert_select "p", text: "Food"
    assert_select "p", text: "Uncategorized"
    assert_select "div.rounded-bar.bg-highlight", 1
  end

  test "shows the year by month" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(period: "year")
    end

    assert_select "p", text: "Spent in 2026"
    assert_select "[data-chart-label-param='October · $5.50']"
    assert_select "p[data-chart-target=readout]", text: ""
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

  test "draws the spending chart by default with a readout label on each column that has spending" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url
    end

    assert_select "nav[aria-label=Chart] a[aria-current=true]", text: "Spending", count: 1
    assert_select "nav[aria-label=Chart] a[href='#{root_path(period: "month", chart: "summary")}']", text: "Summary"
    assert_select "[data-chart-label-param='Oct 1 · $5.50'] .bg-data-strong"
    assert_select "[data-chart-target=readout]", text: ""
    assert_select "[data-chart-target=key]", count: 0
    assert_select "p.basis-0", text: "Oct 1"
    assert_select "p.basis-0", text: "Oct 29"
    assert_select "p.basis-0", text: "Oct 2", count: 0
  end

  test "labels every column when the period has twelve or fewer" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(period: "week")
    end

    assert_select "p.basis-0", count: 7
    assert_select "p.basis-0", text: "Oct 12"
  end

  test "keeps the chart across periods and the period across charts" do
    get root_url(period: "week", chart: "summary")

    assert_select "nav[aria-label=Period] a[href='#{root_path(period: "year", chart: "summary")}']", text: "Year"
    assert_select "nav[aria-label=Chart] a[href='#{root_path(period: "week")}']", text: "Spending"
    assert_select "nav[aria-label=Chart] a[aria-current=true]", text: "Summary"
  end

  test "falls back to the spending chart for an unknown chart" do
    get root_url(chart: "pie")

    assert_select "nav[aria-label=Chart] a[aria-current=true]", text: "Spending"
    assert_select "[data-chart-label-param^='Oct 1']"
  end

  test "summarizes the last six months, each linking to its focus" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -250_000, occurred_on: "2026-09-02")
      users(:one).transactions.create!(name: "Payroll", amount_in_cents: 789_000, occurred_on: "2026-09-01")
      users(:one).transactions.create!(name: "Repairs", amount_in_cents: -50_000, occurred_on: "2026-08-09")

      get root_url(period: "month", chart: "summary")
    end

    assert_select "a[href='#{root_path(period: "month", chart: "summary", focus: "2026-05-01")}']"
    assert_select "a[href='#{root_path(period: "month", chart: "summary", focus: "2026-10-01")}']"
    assert_select "a[href='#{root_path(period: "month", chart: "summary", focus: "2026-09-01")}'][aria-label='Sep · income $7,890 · spent $2,500']" do
      assert_select "span", text: "Sep"
      assert_select "span.text-success", text: "+$5,390"
      assert_select ".bg-data-soft"
    end
    assert_select "a[href*='focus=2026-10-01'][aria-label^='Oct · income']"
    assert_select "a[href*='focus=2026-10-01'] span.text-success", text: "+$1,995"
    assert_select "[data-chart-target=readout]", text: ""
    assert_equal [ "Income", "Spent", "±Net" ], css_select("[data-chart-target=key] > span").map { |span| span.text.strip }
    assert_select "a[href*='focus=2026-08-01'] span.text-tertiary", text: "−$500"
    assert_select "div.flex.gap-1\\.5 > a[aria-current]", count: 0
    assert_select "a .opacity-40", count: 0
    assert_select "p.font-semibold", count: 0
  end

  test "summarizes the last six weeks, each linking to its focus" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -250_000, occurred_on: "2026-10-05")
      users(:one).transactions.create!(name: "Payroll", amount_in_cents: 789_000, occurred_on: "2026-10-11")

      get root_url(period: "week", chart: "summary")
    end

    assert_select "a[href='#{root_path(period: "week", chart: "summary", focus: "2026-09-07")}']", text: /Sep 7/
    assert_select "a[href='#{root_path(period: "week", chart: "summary", focus: "2026-10-12")}'][aria-label='Oct 12 · income $0 · spent $0']"
    assert_select "a[href='#{root_path(period: "week", chart: "summary", focus: "2026-10-05")}'][aria-label='Oct 5 · income $7,890 · spent $2,500']" do
      assert_select "span", text: "Oct 5"
      assert_select "span.text-success", text: "+$5,390"
    end
    assert_select "a[href*='month=']", count: 0
    assert_select "a[href*='focus=2026-09-01']", count: 0
    assert_select "div.flex.gap-1\\.5 > a", count: 6
  end

  test "summarizes the last six years, each linking to its focus" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -250_000, occurred_on: "2024-09-02")
      users(:one).transactions.create!(name: "Payroll", amount_in_cents: 789_000, occurred_on: "2024-03-01")

      get root_url(period: "year", chart: "summary")
    end

    assert_select "a[href='#{root_path(period: "year", chart: "summary", focus: "2021-01-01")}']", text: /2021/
    assert_select "a[href='#{root_path(period: "year", chart: "summary", focus: "2026-01-01")}'][aria-label='2026 · income $2,000 · spent $6']"
    assert_select "a[href='#{root_path(period: "year", chart: "summary", focus: "2024-01-01")}'][aria-label='2024 · income $7,890 · spent $2,500']" do
      assert_select "span", text: "2024"
      assert_select "span.text-success", text: "+$5,390"
    end
    assert_select "a[href*='focus=2020-01-01']", count: 0
  end

  test "focuses one month under the chart with its sources and categories" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Payroll", amount_in_cents: 789_000, occurred_on: "2026-09-01")
      users(:one).transactions.create!(name: "Bonus", amount_in_cents: 100_000, occurred_on: "2026-09-02")
      users(:one).transactions.create!(name: "Interest", amount_in_cents: 1_288, occurred_on: "2026-09-03")
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -165_000, occurred_on: "2026-09-04")
      users(:one).transactions.create!(name: "Soda", amount_in_cents: -250, occurred_on: "2026-09-05", category: categories(:food))

      get root_url(chart: "summary", focus: "2026-09-01")
    end

    unfocused = root_path(period: "month", chart: "summary")
    assert_select "a[href='#{unfocused}'][aria-current=true][aria-label='Sep · income $8,903 · spent $1,653'].bg-level-3" do
      assert_select "span.font-medium.text-primary", text: "Sep"
      assert_select "span.text-success", text: "+$7,250"
      assert_select ".opacity-40", count: 0
    end
    assert_select "div.flex.gap-1\\.5 > a[aria-current]", count: 1
    assert_select "a[href*='focus=2026-08-01'] .opacity-40"
    assert_select "a[href*='focus=2026-08-01'] span.text-secondary", text: "Aug"
    assert_select "[data-chart-target=key]"
    assert_select "[data-chart-target=readout]"
    assert_select "p.font-semibold", text: "September"
    assert_select "p", text: "Income"
    assert_select "p", text: "$8,902.88"
    assert_select "p", text: "Spent"
    assert_select "p", text: "$1,652.50"
    assert_select "span.truncate", text: "Payroll"
    assert_select "span", text: "$7,890.00"
    assert_select "span.truncate", text: "Bonus"
    assert_select "span.truncate", text: "1 more"
    assert_select "span", text: "$12.88"
    assert_select "span", text: "Uncategorized"
    assert_select "span", text: "Food"
    assert_select "div.h-2\\.5[style='width: 100.0%']", count: 1
    assert_select "div.h-2\\.5[style='width: 18.6%']", count: 1
    assert_select "p", text: "Nothing came in.", count: 0
    assert_select "p", text: "Nothing spent.", count: 0
  end

  test "focuses a week and a year by their own names" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Rent", amount_in_cents: -250_000, occurred_on: "2026-10-06")

      get root_url(period: "week", chart: "summary", focus: "2026-10-05")
      assert_select "p.font-semibold", text: "Oct 5–11"
      assert_select "p", text: "$2,500.00"
      assert_select "span", text: "Uncategorized"
      assert_select "p", text: "Income", count: 0

      get root_url(period: "year", chart: "summary", focus: "2025-01-01")
      assert_select "p.font-semibold", text: "2025"
      assert_select "p", text: "Nothing spent."
    end
  end

  test "says nothing was spent in an empty focused period" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(chart: "summary", focus: "2026-03-01")
    end

    assert_select "p.font-semibold", text: "March"
    assert_select "p", text: "Nothing spent."
    assert_select "p", text: "Nothing came in.", count: 0
    assert_select "p", text: "Income", count: 0
    assert_select "p", text: "Spent", count: 0
  end

  test "keeps the categories of a focused period whose refunds outweigh its spending" do
    travel_to Time.utc(2026, 10, 15) do
      users(:one).transactions.create!(name: "Soda", amount_in_cents: -2_500, occurred_on: "2026-06-03", category: categories(:food))
      users(:one).transactions.create!(name: "Rent back", amount_in_cents: 10_000, occurred_on: "2026-06-04", category: categories(:food))
      users(:one).transactions.create!(name: "Cab", amount_in_cents: -1_200, occurred_on: "2026-06-05")

      get root_url(chart: "summary", focus: "2026-06-01")
    end

    assert_select "p", text: "Spent"
    assert_select "p", text: "−$63.00"
    assert_select "span", text: "Uncategorized"
    assert_select "span", text: "$12.00"
    assert_select "p", text: "Nothing spent.", count: 0
  end

  test "clamps a future focus to the current period" do
    travel_to Time.utc(2026, 10, 15) do
      get root_url(chart: "summary", focus: "2030-01-01")
    end

    assert_select "p.font-semibold", text: "October"
    assert_select "a[aria-current=true][aria-label^='Oct ·']"
  end

  test "ignores a focus outside the summary chart" do
    get root_url(focus: "2026-09-01")

    assert_select "p.font-semibold", count: 0
    assert_select "[data-chart-target=readout]"
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

  test "offers the sidebar on phones as a sheet with the same links" do
    get root_url

    assert_select "header button[aria-label='Show sidebar']"
    assert_select "dialog[aria-label=Sidebar] a", text: /\A(Overview|Transactions|Categories|Trends|Import|Settings)\z/, count: 6
    assert_select "dialog[aria-label=Sidebar] a[aria-current=page]", text: "Overview", count: 1
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
    assert_select "turbo-frame#voucher [data-shorthand=?]", "Blue Bottle 5.50", text: /ok · \$5.50/
  end

  test "gives the bar the user's category names in name order" do
    users(:one).categories.create!(name: "groceries")
    users(:one).categories.create!(name: "Bills")
    users(:two).categories.create!(name: "Secret")

    get root_url

    assert_select "[data-composer-categories-value=?]", '["Bills","Food","groceries","Income"]'
  end
end
