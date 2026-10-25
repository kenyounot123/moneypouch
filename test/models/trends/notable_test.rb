require "test_helper"

class Trends::NotableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.transactions.destroy_all
    @today = Date.new(2026, 10, 15)
  end

  test "below usual: names the category furthest under its usual last month, linking to that month" do
    food_months 10_000, 10_000, 10_000, 10_000, 10_000, 7_900

    note = below_usual

    assert_equal [ :below_usual, :good, "You spent less than usual on Food in September.", category_path(categories(:food), month: "2026-09") ], note.to_h.values_at(:kind, :tone, :text, :path)
  end

  test "below usual: needs at least $20 under" do
    food_months 10_000, 10_000, 10_000, 10_000, 10_000, 8_000
    assert below_usual

    @user.transactions.destroy_all
    food_months 10_000, 10_000, 10_000, 10_000, 10_000, 8_001
    assert_nil below_usual
  end

  test "below usual: needs at least 10% under" do
    food_months 50_000, 50_000, 50_000, 50_000, 50_000, 45_000
    assert below_usual

    @user.transactions.destroy_all
    food_months 50_000, 50_000, 50_000, 50_000, 50_000, 45_001
    assert_nil below_usual
  end

  test "below usual: says nothing without a usual, for uncategorized money, or when this month is the low one" do
    add(-5_000, "2026-09-12", "One month only", categories(:food))
    add(-10_000, "2026-08-12", "Mystery")
    add(-10_000, "2026-07-12", "Mystery")
    add(-10_000, "2026-06-12", "Mystery")
    add(-10_000, "2026-05-12", "Mystery")
    add(-10_000, "2026-04-12", "Mystery")

    assert_nil below_usual
  end

  test "lowest since: the last full month is below the four before it, back to the month that was as low" do
    add(-1_000, "2026-03-10", "Meal", categories(:food))
    food_months 9_000, 8_000, 7_000, 6_000, 5_000, 4_000

    note = lowest_since

    assert_equal [ :lowest_since, :good, "September was your lowest Food month since March.", category_path(categories(:food), month: "2026-09") ], note.to_h.values_at(:kind, :tone, :text, :path)
  end

  test "lowest since: needs four higher months right before" do
    add(-1_000, "2026-05-10", "Meal", categories(:food))
    food_months 0, 7_000, 6_000, 5_000, 4_000
    assert_nil lowest_since

    @user.transactions.destroy_all
    add(-1_000, "2026-04-10", "Meal", categories(:food))
    food_months 0, 7_000, 6_000, 5_000, 4_000, 3_000
    assert lowest_since
  end

  test "lowest since: a month as low as the last one ends the run" do
    food_months 5_000, 5_000, 6_000, 7_000, 8_000, 5_000

    assert_nil lowest_since
  end

  test "lowest since: with nothing as low in the whole window, counts the months it can see" do
    (1..10).each { |back| add(-(10_000 + back), (Date.new(2026, 9, 10) << back).to_s, "Meal", categories(:food)) }
    add(-5_000, "2026-09-10", "Meal", categories(:food))

    assert_equal "September was your lowest Food month in 11 months.", lowest_since.text
  end

  test "lowest since: an empty month before the run counts the months instead of naming it" do
    food_months 9_000, 8_000, 7_000, 6_000, 5_000, 4_000

    assert_equal "September was your lowest Food month in 6 months.", lowest_since.text
  end

  test "lowest since: an empty last month is not a lowest month" do
    food_months 9_000, 8_000, 7_000, 6_000, 5_000, 0

    assert_nil lowest_since
  end

  test "positive net months: counts the last six full months with a positive net" do
    positive_net_in "2026-09", "2026-07", "2026-04"

    assert_equal [ :positive_net_months, :good, "Your net was positive in 3 of the last 6 months.", nil ], positive_net_months.to_h.values_at(:kind, :tone, :text, :path)
  end

  test "positive net months: stays quiet below three, and leaves out this month and the ones before the six" do
    positive_net_in "2026-09", "2026-07", "2026-03", "2026-10"

    assert_nil positive_net_months
  end

  test "charge stopped: a monthly charge that last came the month before last month, once this month is past its day" do
    spotify

    assert_equal [ :charge_stopped, :neutral, "Your Spotify charge stopped.", nil ], charge_stopped.to_h.values_at(:kind, :tone, :text, :path)
  end

  test "charge stopped: waits for this month to pass the usual day" do
    spotify

    assert_nil charge_stopped(Date.new(2026, 10, 3))
    assert charge_stopped(Date.new(2026, 10, 4))
  end

  test "charge stopped: says nothing while the charge still comes, or when it stopped long before" do
    spotify
    add(-1_549, "2026-09-03", "Spotify")
    assert_nil charge_stopped

    @user.transactions.destroy_all
    [ "2026-03-03", "2026-04-03", "2026-05-03", "2026-06-03", "2026-07-03" ].each { |on| add(-1_549, on, "Spotify") }
    assert_nil charge_stopped
  end

  test "new income: names an income source first seen last month or this month" do
    add 100_000, "2026-07-01", "Acme"
    add 100_000, "2026-09-01", "Acme"
    add 5_000, "2026-09-02", "Side gig"
    add 9_000, "2026-10-02", "Refund"

    assert_equal [ :new_income, :good, "New income from Refund.", nil ], new_income.to_h.values_at(:kind, :tone, :text, :path)
  end

  test "new income: says nothing for a source seen before last month" do
    add 100_000, "2026-08-31", "Acme"
    add 100_000, "2026-09-01", "Acme"
    add 100_000, "2026-10-01", "ACME"

    assert_nil new_income
  end

  test "keeps at most four, lowest since first and new income last" do
    fun = @user.categories.create!(name: "Fun")
    food_months 9_000, 8_000, 7_000, 6_000, 5_000, 4_000
    [ 10_000, 10_000, 10_000, 4_000, 10_000, 5_000 ].each.with_index(4) { |cents, month| add(-cents, format("2026-%02d-10", month), "Show", fun) }
    (4..9).each { |month| add 50_000, format("2026-%02d-01", month), "Pay" }
    spotify
    add 5_000, "2026-10-02", "Side gig"

    assert_equal %i[ lowest_since below_usual positive_net_months charge_stopped ], trends.notes.map(&:kind)
  end

  test "keeps one note per category and month, lowest since over below usual" do
    food_months 10_000, 10_000, 10_000, 10_000, 10_000, 5_000

    assert_equal [ :lowest_since ], trends.notes.map(&:kind)
  end

  test "leaves out the notes with nothing to say" do
    spotify

    assert_equal [ :charge_stopped ], trends.notes.map(&:kind)
  end

  private
    def trends
      Trends.new(@user.transactions, today: @today)
    end

    def below_usual
      trends.below_usual_note
    end

    def lowest_since
      trends.lowest_since_note
    end

    def new_income
      trends.new_income_note
    end

    def charge_stopped(today = @today)
      Trends.new(@user.transactions, today:).charge_stopped_note
    end

    def spotify
      [ "2026-04-03", "2026-05-03", "2026-06-03", "2026-07-03", "2026-08-03" ].each { |on| add(-1_549, on, "Spotify") }
    end

    def positive_net_months
      trends.positive_net_months_note
    end

    # Food spending per month, ending with September and going back.
    def food_months(*cents)
      cents.reverse.each_with_index do |amount, back|
        add(-amount, (Date.new(2026, 9, 10) << back).to_s, "Meal", categories(:food)) if amount.positive?
      end
    end

    def positive_net_in(*months)
      (4..9).each { |month| add(-1_000, format("2026-%02d-02", month), "Rent") }
      months.each { |month| add 5_000, "#{month}-01", "Pay" }
    end

    def add(cents, occurred_on, name, category = nil)
      @user.transactions.create!(name:, amount_in_cents: cents, occurred_on:, category:)
    end

    def category_path(...)
      Rails.application.routes.url_helpers.category_path(...)
    end
end
