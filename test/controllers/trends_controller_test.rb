require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
    users(:one).transactions.destroy_all
  end

  test "asks for a sign in" do
    delete session_url

    get trends_url

    assert_redirected_to new_session_url
  end

  test "marks Trends as the current page in the sidebar and links the other pages" do
    get trends_url

    assert_response :success
    assert_select "h1", text: "Trends"
    assert_select "aside a[aria-current=page]", text: "Trends", count: 1
    assert_select "aside a[href='#{trends_path}']", text: "Trends"
  end

  test "waits for two full months and shows how far along that is" do
    add 1_000, "2026-08-04", "One full month"

    get trends_url

    assert_select "main p", text: "Trends fill in after your first full month."
    assert_select "[role=meter][aria-label='Full months'][aria-valuemin='0'][aria-valuemax='2'][aria-valuenow='1']"
    assert_select "main h2", count: 0
  end

  test "sums the year in a sentence and keeps money only when there is some" do
    add 500_000, "2026-09-01", "Pay"
    add(-200_000, "2026-09-02", "Rent")
    add 100_000, "2026-08-01", "Pay"
    add(-300_000, "2026-08-02", "Rent")
    add(-1_250, "2026-10-14", "Coffee")

    get trends_url

    assert_select "[role=meter]", count: 0
    assert_select "section[aria-labelledby=glance-heading] > p", text: "Over the last 12 months you earned $6,000.00 and spent $5,012.50. You kept $987.50."
    assert_select "section[aria-labelledby=glance-heading] > p span.text-success", text: "$987.50"
  end

  test "charts the 12 months, each linking to its transactions, the current one so far" do
    add 500_000, "2026-09-01", "Pay"
    add(-200_000, "2026-09-02", "Rent")
    add 100_000, "2026-08-01", "Pay"
    add(-300_000, "2026-08-02", "Rent")
    add(-1_250, "2026-10-14", "Coffee")

    get trends_url

    assert_select "[role=group][aria-label=Months] > a", count: 12
    assert_select "a[href='#{transactions_path(month: "2025-11")}']", count: 1
    assert_select "a[href='#{transactions_path(month: "2026-10")}'][aria-label='Oct · income $0 · spent $13 so far']" do
      assert_select "div.opacity-50"
      assert_select "span", text: "so far"
    end
    assert_select "a[href='#{transactions_path(month: "2026-09")}'][aria-label='Sep · income $5,000 · spent $2,000']" do
      assert_select "div.opacity-50", count: 0
      assert_select "span.text-success", text: "$3,000"
    end
    assert_select "a[href='#{transactions_path(month: "2026-08")}']" do
      assert_select "span", text: /Kept/, count: 0
    end
  end

  test "lists spending categories largest first, then income, each with a sparkline, this month so far and its usual" do
    [ "2026-04", "2026-05", "2026-06", "2026-07", "2026-08", "2026-09" ].each { |month| add(-10_000, "#{month}-10", "Meal", categories(:food)) }
    add(-2_550, "2026-10-03", "Lunch", categories(:food))
    add(-500, "2026-10-04", "Gum")
    add 300_000, "2026-09-01", "Pay", categories(:income)

    get trends_url

    assert_select "section[aria-labelledby=categories-heading] h3", text: /Spending|Income/, count: 2
    assert_select "section[aria-labelledby=categories-heading] ul:first-of-type li p.min-w-0", text: /\S/ do |names|
      assert_equal [ "Food", "Uncategorized" ], names.map { |name| name.text.strip }
    end
    assert_select "li", text: /Food/ do
      assert_select "a[href='#{category_path(categories(:food), month: "2026-10")}']", text: "Food"
      assert_select "div[aria-hidden=true] > div", count: 12
      assert_select "p.font-mono", text: "$25.50"
      assert_select "p.text-tertiary", text: "usually $100.00"
    end
    assert_select "li", text: /Uncategorized/ do
      assert_select "a", count: 0
      assert_select "p.text-tertiary", text: /usually/, count: 0
    end
    assert_select "li", text: /Income/ do
      assert_select "a[href='#{category_path(categories(:income), month: "2026-10")}']", text: "Income"
      assert_select "p.font-mono", text: "$0.00"
    end
  end

  private
    def add(cents, occurred_on, name, category = nil)
      users(:one).transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
