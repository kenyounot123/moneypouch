require "test_helper"

class TrendsToneTest < ActionDispatch::IntegrationTest
  BANNED_WORDS = /over budget|overspent|worst|watch out|too much|increase|higher than/i
  BANNED_STYLES = /text-danger|\bred-/
  ARROWS = /[▲▼↑↓⬆⬇]/

  test "the Trends source never says or colors anything as bad news" do
    sources = Rails.root.glob([ "app/views/trends/**/*", "app/models/trends.rb", "app/models/trends/**/*", "app/helpers/trends_helper.rb" ]).select(&:file?)

    assert_operator sources.size, :>=, 8
    sources.each do |source|
      text = source.read

      assert_no_match BANNED_WORDS, text, source.to_s
      assert_no_match BANNED_STYLES, text, source.to_s
      assert_no_match ARROWS, text, source.to_s
    end
  end

  test "a page where spending grew and a month ended in the red shows no loss, flag, or negative money" do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
    users(:one).transactions.destroy_all
    add 100_000, "2026-08-01", "Pay"
    add(-300_000, "2026-08-02", "Rent")
    add(-10_000, "2026-08-10", "Meal", categories(:food))
    add 500_000, "2026-09-01", "Pay"
    add(-30_000, "2026-09-10", "Meal", categories(:food))
    add(-900_000, "2026-10-05", "Trip", categories(:food))
    add(-1_000, "2026-10-06", "Gum")
    [ "2026-08-03", "2026-09-03" ].each { |on| add(-1_549, on, "Spotify") }
    add(-1_799, "2026-10-03", "Spotify")

    get trends_url

    assert_response :success
    assert_select "main", text: /Food/
    assert_select "main", text: /now \$17.99, was \$15.49/
    assert_no_match MoneyHelper::MINUS, response.body
    assert_no_match BANNED_STYLES, response.body
    assert_no_match BANNED_WORDS, css_select("main").text
    assert_no_match ARROWS, css_select("main").text
    assert_no_match "%", css_select("main").text
    assert_select "a[aria-label^='Aug']" do
      assert_select "span", text: /Kept/, count: 0
    end
  end

  private
    def add(cents, occurred_on, name, category = nil)
      users(:one).transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end
end
