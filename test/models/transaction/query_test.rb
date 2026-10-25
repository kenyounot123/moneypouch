require "test_helper"

class Transaction::QueryTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 25)

  setup do
    @user = users(:one)
    @eating_out = @user.categories.create!(name: "Eating Out")
    @eating_plans = @user.categories.create!(name: "Eating Plans")
    @user.categories.create!(name: "Eat")
    users(:two).categories.create!(name: "Secret")
  end

  test "reads each kind of token into a part" do
    {
      "#food" => [ :category, "Food" ],
      "#FOO" => [ :category, "Food" ],
      "#eatingout" => [ :category, "Eating Out" ],
      "#eating" => [ :category, "Eating Out" ],
      "#eat" => [ :category, "Eat" ],
      "in:typed" => [ :account, "Typed in" ],
      ">50" => [ :amount, "Over $50" ],
      "<12.5" => [ :amount, "Under $12.50" ],
      ">$1000" => [ :amount, "Over $1,000" ],
      "50..100" => [ :amount, "$50–$100" ],
      "100..50" => [ :amount, "$50–$100" ],
      "=12.99" => [ :amount, "$12.99" ],
      "$12.99" => [ :amount, "$12.99" ],
      "@today" => [ :date, "Today" ],
      "@yesterday" => [ :date, "Yesterday" ],
      "@7d" => [ :date, "Last 7 days" ],
      "@30d" => [ :date, "Last 30 days" ],
      "@90d" => [ :date, "Last 90 days" ],
      "@year" => [ :date, "This year" ],
      "@sep" => [ :date, "September 2026" ],
      "@SEPT" => [ :date, "September 2026" ],
      "@november" => [ :date, "November 2025" ],
      "@oct" => [ :date, "October 2026" ],
      "@2025-09" => [ :date, "September 2025" ],
      "?" => [ :status, "Needs a category" ],
      "+" => [ :status, "Money in" ],
      "-" => [ :status, "Money out" ],
      "coffee" => [ :text, "“coffee”" ],
      %("blue bottle") => [ :text, "“blue bottle”" ],
      "#" => [ :category, "#" ],
      "in:" => [ :account, "in:" ]
    }.each do |raw, (kind, label)|
      part = parse(raw).parts.sole

      assert_equal [ kind, raw, label ], [ part.kind, part.raw, part.label ], raw
    end
  end

  test "a token that matches nothing is kept with a sentence saying why" do
    {
      "#nothing" => "No category matches “nothing”.",
      "#-" => "No category matches “-”.",
      "in:nowhere" => "No account matches “nowhere”.",
      "@whenever" => "“whenever” isn’t a date.",
      "@ju" => "“ju” isn’t a date.",
      "@2025-13" => "“2025-13” isn’t a date.",
      "@2027-01" => "January 2027 hasn’t started."
    }.each do |raw, problem|
      assert_equal [ raw, problem ], parse(raw).parts.sole.then { |part| [ part.raw, part.problem ] }
    end
  end

  test "another user's categories and accounts never match" do
    assert_equal "No category matches “secret”.", parse("#secret").parts.sole.problem
    assert_nil parse("#food").parts.sole.problem
  end

  test "splits on whitespace and keeps a quoted phrase whole" do
    query = parse(%(#food  "blue bottle" >5 tea))

    assert_equal [ "#food", %("blue bottle"), ">5", "tea" ], query.parts.map(&:raw)
    assert_equal [ :category, :text, :amount, :text ], query.parts.map(&:kind)
    assert_empty parse(%( "" "  " )).parts
    assert_equal [ %("blue bo) ], parse(%("blue bo)).parts.map(&:raw)
  end

  test "a later amount or date replaces an earlier one, which keeps its chip with a problem" do
    query = parse(">5 <20 @7d @sep #food #eat")

    assert_equal [ "Replaced by a later amount.", nil, "Replaced by a later date.", nil, nil, nil ], query.parts.map(&:problem)
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), query.dates
  end

  test "an unreadable later date does not replace a readable earlier one" do
    query = parse("@7d @whenever")

    assert_equal (TODAY - 6)..TODAY, query.dates
    assert_equal [ nil, "“whenever” isn’t a date." ], query.parts.map(&:problem)
  end

  test "dates are the date token's range, and month is set only for a calendar month" do
    {
      "#food" => [ nil, nil ],
      "@today" => [ TODAY..TODAY, nil ],
      "@yesterday" => [ Date.new(2026, 10, 24)..Date.new(2026, 10, 24), nil ],
      "@7d" => [ Date.new(2026, 10, 19)..TODAY, nil ],
      "@30d" => [ Date.new(2026, 9, 26)..TODAY, nil ],
      "@90d" => [ Date.new(2026, 7, 28)..TODAY, nil ],
      "@year" => [ Date.new(2026, 1, 1)..TODAY, nil ],
      "@sep" => [ Date.new(2026, 9, 1)..Date.new(2026, 9, 30), Date.new(2026, 9, 1) ],
      "@dec" => [ Date.new(2025, 12, 1)..Date.new(2025, 12, 31), Date.new(2025, 12, 1) ],
      "@2025-02" => [ Date.new(2025, 2, 1)..Date.new(2025, 2, 28), Date.new(2025, 2, 1) ],
      "@oct" => [ Date.new(2026, 10, 1)..Date.new(2026, 10, 31), Date.new(2026, 10, 1) ]
    }.each do |raw, (dates, month)|
      query = parse(raw)

      assert_equal [ dates, month ], [ query.dates, query.month&.first_day ], raw
    end
  end

  test "a rolling range is not a calendar month even when it happens to cover one" do
    january = Transaction::Query.parse("@year", user: @user, today: Date.new(2026, 1, 31))

    assert_nil january.month
  end

  test "only valid parts narrow, so a query of problems is not filtering" do
    assert_not parse("").filtering?
    assert_not parse("#nothing @whenever").filtering?
    assert parse("#nothing tea").filtering?
  end

  test "scopes by name or note, and several words must all match" do
    seed_transactions

    {
      "bottle" => [ "Blue Bottle" ],
      "BIRTHDAY" => [ "Din Din Cafe" ],
      %("din din") => [ "Din Din Cafe" ],
      "din bday" => [],
      "din birthday" => [ "Din Din Cafe" ]
    }.each do |q, names|
      assert_equal names, names_for(q), q
    end
  end

  test "scopes by category, with several categories adding up" do
    seed_transactions

    {
      "#eatingout" => [ "Din Din Cafe" ],
      "#food" => [ "Blue Bottle" ],
      "#eatingout #food" => [ "Blue Bottle", "Din Din Cafe" ],
      "#food tea" => [],
      "#nothing" => [ "Blue Bottle", "Din Din Cafe", "Gas", "Gas Station Big", "Paycheck", "Refund Store" ]
    }.each do |q, names|
      assert_equal names, names_for(q), q
    end
  end

  test "scopes by amount without regard to direction" do
    seed_transactions

    {
      ">30" => [ "Gas Station Big", "Paycheck", "Refund Store" ],
      "<12.5" => [ "Blue Bottle" ],
      "<12.51" => [ "Blue Bottle", "Gas" ],
      "30..50" => [ "Din Din Cafe", "Refund Store" ],
      "=12.50" => [ "Gas" ],
      "$50" => [ "Refund Store" ],
      ">30 <60" => [ "Blue Bottle", "Din Din Cafe", "Gas", "Refund Store" ]
    }.each do |q, names|
      assert_equal names.sort, names_for(q).sort, q
    end
  end

  test "scopes by status" do
    seed_transactions

    {
      "+" => [ "Paycheck", "Refund Store" ],
      "-" => [ "Blue Bottle", "Din Din Cafe", "Gas", "Gas Station Big" ],
      "+ -" => [],
      "? #food" => []
    }.each do |q, names|
      assert_equal names.sort, names_for(q).sort, q
    end
  end

  test "scopes by account, with several accounts adding up and typed-in rows apart" do
    access = connect_simplefin(@user)
    activate(access)
    savings = @user.bank_accounts.find_by!(name: "SimpleFIN Savings")
    checking = @user.bank_accounts.find_by!(name: "SimpleFIN Checking")

    {
      "in:savings" => savings.transactions,
      "in:simplefinsavings" => savings.transactions,
      "in:simplefin" => checking.transactions,
      "in:savings in:checking" => savings.transactions.or(checking.transactions),
      "in:typed" => @user.transactions.typed_in,
      "?" => @user.transactions.needing_category,
      "in:savings >100" => savings.transactions.where("abs(amount_in_cents) > 10000")
    }.each do |q, expected|
      assert_equal expected.order(:id).ids, scoped(q).order(:id).ids, q
    end
  end

  test "an account is found by any word of its name" do
    access = connect_simplefin(@user)
    access.bank_accounts.create!(external_id: "gold", name: "Amex Gold", currency: "USD")

    {
      "in:amex" => "Amex Gold",
      "in:gold" => "Amex Gold",
      "in:amexgold" => "Amex Gold",
      "in:AMEX-gold" => "Amex Gold"
    }.each do |raw, label|
      assert_equal label, parse(raw).parts.sole.label, raw
    end
  end

  test "scopes by date range" do
    seed_transactions

    assert_equal [ "Din Din Cafe", "Refund Store" ], names_for("@sep")
    assert_equal [ "Blue Bottle", "Paycheck" ], names_for("@oct")
    assert_equal [ "Gas" ], names_for("@2026-08")
  end

  test "scope can leave out one token, to count what that token would narrow" do
    seed_transactions
    query = parse("#food ?")

    assert_equal [ "Blue Bottle" ], query.scope(@user.transactions, except: "?").order(:id).pluck(:name)
    assert_empty query.scope(@user.transactions)
  end

  test "to_s, adding and without round-trip the raw tokens" do
    query = parse(%(#din >30 "blue bottle"))

    assert_equal %(#din >30 "blue bottle"), query.to_s
    assert_equal %(#din >30 "blue bottle" in:amex), query.adding("in:amex")
    assert_equal %(#din "blue bottle"), query.without(1)
    assert_equal %(>30 "blue bottle"), query.without(0)
    assert_equal "", parse("tea").without(0)
    assert_equal query.to_s, parse(query.adding("@sep")).without(3).to_s
  end

  test "toggle adds a token, or removes it when it is there" do
    assert_equal "#food ?", parse("#food").toggle("?")
    assert_equal "#food", parse("#food ?").toggle("?")
  end

  test "without_dates drops every date token, readable or not" do
    assert_equal "#food tea", parse("#food @30d tea @whenever").without_dates
    assert_equal "", Transaction::Query.blank.without_dates
  end

  test "with_month swaps any date token for the month, or appends one" do
    september = Period.month("2026-09", today: TODAY)

    assert_equal "@2026-09", parse("").with_month(september)
    assert_equal "#food @2026-09", parse("#food").with_month(september)
    assert_equal "#food @2026-09", parse("#food @30d").with_month(september)
    assert_equal ">5 @2026-09", parse("@oct >5 @whenever").with_month(september)
    assert_equal "@2026-09", parse(parse("@oct").with_month(september)).to_s
    assert_equal september, parse(parse("tea").with_month(september)).month
  end

  test "canonical tokens read back as the record they name" do
    access = connect_simplefin(@user)
    account = access.bank_accounts.create!(external_id: "gold", name: "Amex Gold", currency: "USD")
    category = categories(:food)

    assert_equal "#food", Transaction::Query.category_token(category)
    assert_equal "in:amexgold", Transaction::Query.account_token(account)
    assert_equal %("Whole Foods"), Transaction::Query.text_token("Whole Foods")
    assert_equal %("5 inch"), Transaction::Query.text_token(%(5" inch))
    assert_equal "Food", parse(Transaction::Query.category_token(category)).parts.sole.label
    assert_equal "Amex Gold", parse(Transaction::Query.account_token(account)).parts.sole.label
    assert_equal "Eating Out", parse(Transaction::Query.category_token(@eating_out)).parts.sole.label
  end

  private
    def parse(string)
      Transaction::Query.parse(string, user: @user, today: TODAY)
    end

    def scoped(string)
      parse(string).scope(@user.transactions)
    end

    def names_for(string)
      scoped(string).order(:name).pluck(:name)
    end

    def seed_transactions
      @user.transactions.create!(name: "Din Din Cafe", note: "birthday", amount_in_cents: -3_000, occurred_on: "2026-09-14", category: @eating_out)
      @user.transactions.create!(name: "Gas", amount_in_cents: -1_250, occurred_on: "2026-08-02")
      @user.transactions.create!(name: "Gas Station Big", amount_in_cents: -9_000, occurred_on: "2026-07-02")
      @user.transactions.create!(name: "Refund Store", amount_in_cents: 5_000, occurred_on: "2026-09-05")
    end
end
