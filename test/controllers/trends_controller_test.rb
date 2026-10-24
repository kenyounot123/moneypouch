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

    assert_select "main p", text: "Trends fill in once you have two full months of transactions."
    assert_select "[role=meter][aria-label='Full months'][aria-valuemin='0'][aria-valuemax='2'][aria-valuenow='1']"
    assert_select "main p", text: "1 of 2 months"
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
    assert_select "section[aria-labelledby=glance-heading] > p", text: "You earned $6,000.00 and spent $5,012.50. You kept $987.50."
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

  test "lists spending categories largest first, each with a sparkline, this month so far and its usual" do
    [ "2026-04", "2026-05", "2026-06", "2026-07", "2026-08", "2026-09" ].each { |month| add(-10_000, "#{month}-10", "Meal", categories(:food)) }
    add(-2_550, "2026-10-03", "Lunch", categories(:food))
    add(-500, "2026-10-04", "Gum")
    add 300_000, "2026-09-01", "Pay", categories(:income)

    get trends_url

    assert_select "section[aria-labelledby=categories-heading] > div[aria-hidden=true]", text: /Nov–Oct\s+October so far/
    assert_select "section[aria-labelledby=categories-heading] li p.min-w-0", text: /\S/ do |names|
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
    assert_select "section[aria-labelledby=categories-heading] a", text: "Income", count: 0
  end

  test "shares good news in success green, linking to the month it is about, and hides the section without any" do
    add_two_full_months
    get trends_url
    assert_select "[aria-labelledby=notes-heading]", count: 0

    [ 10_000, 10_000, 10_000, 10_000, 10_000, 7_000 ].each_with_index do |cents, index|
      add(-cents, (Date.new(2026, 4, 10) >> index).to_s, "Meal", categories(:food))
    end
    add 500_000, "2026-08-01", "Pay"

    get trends_url

    assert_select "section[aria-labelledby=notes-heading] h2", text: "Good news"
    assert_select "section[aria-labelledby=notes-heading] li.text-success a[href='#{category_path(categories(:food), month: "2026-09")}']", text: "September was your lowest Food month in 6 months."
  end

  test "lists recurring charges largest first with their usual day, a price change, and what they come to a month" do
    [ "2026-08-03", "2026-09-03" ].each { |on| add(-1_549, on, "Spotify") }
    add(-1_799, "2026-10-03", "Spotify")
    [ "2026-08-01", "2026-09-01", "2026-10-01" ].each { |on| add(-120_000, on, "Rent") }

    get trends_url

    assert_select "section[aria-labelledby=recurring-heading]" do
      assert_select "h2", text: "Recurring charges"
      assert_select "p.text-sm", text: "$1,217.99 a month"
      assert_select "li p.truncate", text: /\S/ do |names|
        assert_equal [ "Rent", "Spotify" ], names.map { |name| name.text.strip }
      end
      assert_select "li", text: /Spotify/ do
        assert_select "p.text-xs", text: "Usually on the 3rd · was $15.49"
        assert_select "p.font-mono", text: "$17.99"
      end
      assert_select "li p.text-xs", text: "Usually on the 1st"
    end
  end

  test "has no recurring section without a recurring charge" do
    add_two_full_months
    add(-1_549, "2026-09-03", "Spotify")

    get trends_url

    assert_select "[aria-labelledby=glance-heading]"
    assert_select "[aria-labelledby=recurring-heading]", count: 0
  end

  test "lists income sources with what they brought in and the days they usually arrive" do
    [ "2026-08-01", "2026-09-01", "2026-10-01" ].each { |on| add 200_000, on, "Acme payroll" }
    [ "2026-08-15", "2026-09-15", "2026-10-15" ].each { |on| add 200_000, on, "Acme payroll" }
    add 12_345, "2026-09-09", "Interest"

    get trends_url

    assert_select "section[aria-labelledby=income-heading]" do
      assert_select "h2", text: "Income"
      assert_select "li", text: /Acme payroll/ do
        assert_select "p.text-xs", text: "Usually arrives on the 1st and 15th"
        assert_select "p.font-mono", text: "$12,000.00"
      end
      assert_select "li", text: /Interest/ do
        assert_select "p.text-xs", count: 0
        assert_select "p.font-mono", text: "$123.45"
      end
    end
  end

  test "has no income section without income" do
    add_two_full_months

    get trends_url

    assert_select "[aria-labelledby=glance-heading]"
    assert_select "[aria-labelledby=income-heading]", count: 0
  end

  private
    def add_two_full_months
      add(-100, "2026-08-02", "Snack")
      add(-200, "2026-09-02", "Snack")
    end

    def add(cents, occurred_on, name, category = nil)
      users(:one).transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
