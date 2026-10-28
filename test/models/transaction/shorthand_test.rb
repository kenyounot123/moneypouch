require "test_helper"

class Transaction::ShorthandTest < ActiveSupport::TestCase
  SUNDAY = Date.new(2026, 9, 27)
  Aim = Transaction::Shorthand::Aim

  test "reads an amount typed alone, as the composer would" do
    assert_equal(-12_486, Transaction::Shorthand.amount_in_cents("124.86"))
    assert_equal(-120_000, Transaction::Shorthand.amount_in_cents(" $1,200 "))
    assert_equal 240_000, Transaction::Shorthand.amount_in_cents("+2400")
  end

  test "an amount that is unreadable or zero is nil" do
    [ "abc", "0", "", "  ", "1 2", nil ].each { assert_nil Transaction::Shorthand.amount_in_cents(_1), _1.inspect }
  end

  test "reads a plain amount as money out" do
    assert_equal({ name: "coffee", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("coffee 5"))
  end

  test "reads cents and a dollar sign" do
    assert_equal({ name: "coffee", amount_in_cents: -550, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("coffee $5.5"))
  end

  test "reads a leading plus as money in" do
    assert_equal({ name: "paycheck", amount_in_cents: 200000, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("+2000 paycheck"))
  end

  test "takes the last bare number when no amount is marked" do
    assert_equal({ name: "7 eleven", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("7 eleven 5"))
    assert_equal({ name: "Route 66 diner", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("Route 66 diner 12"))
  end

  test "prefers a marked amount over bare numbers" do
    assert_equal({ name: "Forever 21", amount_in_cents: -4000, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("Forever 21 $40"))
    assert_equal({ name: "Studio 54", amount_in_cents: -2050, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("Studio 54 20.50"))
  end

  test "takes the first of two marked amounts" do
    assert_equal({ name: "gift $5", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("$12 gift $5"))
  end

  test "reads thousands commas, bare cents, and a minus sign" do
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("rent 1,650"))
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("rent $1,650.00"))
    assert_equal({ name: "gum", amount_in_cents: -50, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("gum .50"))
    assert_equal({ name: "coffee", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("coffee -5"))
  end

  test "keeps a misgrouped comma in the name" do
    assert_equal({ name: "rent 16,50", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50" ] },
      read("rent 16,50"))
  end

  test "drops trailing punctuation from a hash word" do
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: "food", occurred_on: SUNDAY, dated: false, errors: [] },
      read("lunch 12 #food,"))
    assert_equal({ name: "lunch #!", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("lunch #! 12"))
  end

  test "reads a hash word as the category" do
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: "Food", occurred_on: SUNDAY, dated: false, errors: [] },
      read("#Food lunch 12"))
  end

  test "takes a bare hash out of the name and leaves the category to inference" do
    assert_equal({ name: "Trader Joe's", amount_in_cents: -6412, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("Trader Joe's 64.12 #"))
  end

  test "reads every date word the calendar writes" do
    assert_equal [ SUNDAY, Date.new(2026, 9, 26), Date.new(2026, 8, 27), Date.new(2025, 12, 31) ],
      [ "Lyft 9 today", "Lyft 9 yesterday", "Lyft 9 aug 27", "Lyft 9 dec 31 2025" ].map { |shorthand| read(shorthand)[:occurred_on] }
  end

  test "reads yesterday" do
    assert_equal({ name: "coffee", amount_in_cents: -550, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("coffee 5.50 Yesterday"))
  end

  test "reads today" do
    assert_equal({ name: "coffee", amount_in_cents: -550, category_word: nil, occurred_on: SUNDAY, dated: true, errors: [] },
      read("today coffee 5.50"))
  end

  test "reads a weekday as the latest one before today" do
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: "food", occurred_on: Date.new(2026, 9, 25), dated: true, errors: [] },
      read("lunch $12 #food friday"))
  end

  test "reads today's weekday as today" do
    monday = Date.new(2026, 9, 28)
    assert_equal({ name: "spotify", amount_in_cents: -999, category_word: nil, occurred_on: monday, dated: true, errors: [] },
      read("monday 9.99 spotify", today: monday))
  end

  test "reads a month name and day before the amount" do
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("Sept 26 rent 1650"))
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("rent 1650 sep 26"))
  end

  test "reads a month, day, and year" do
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: Date.new(2025, 9, 26), dated: true, errors: [] },
      read("sep 26 2025 rent 1650"))
  end

  test "reads a four digit number outside the year window after a month and day as the amount" do
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("sep 26 1650 rent"))
  end

  test "reads ordinal days" do
    assert_equal({ name: "rent", amount_in_cents: -165000, category_word: nil, occurred_on: Date.new(2026, 9, 1), dated: true, errors: [] },
      read("sep 1st rent 1650"))
    assert_equal({ name: "coffee", amount_in_cents: -500, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("Sep 26TH coffee 5"))
  end

  test "reads a month and day with no year as the latest past one" do
    assert_equal({ name: "gift", amount_in_cents: -4000, category_word: nil, occurred_on: Date.new(2026, 12, 30), dated: true, errors: [] },
      read("dec 30 gift 40", today: Date.new(2027, 1, 2)))
  end

  test "reads feb 29 as the last leap day" do
    assert_equal({ name: "cake", amount_in_cents: -800, category_word: nil, occurred_on: Date.new(2024, 2, 29), dated: true, errors: [] },
      read("february 29 cake 8", today: Date.new(2027, 3, 1)))
  end

  test "reads a slash date" do
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: nil, occurred_on: Date.new(2025, 12, 31), dated: true, errors: [] },
      read("12/31 lunch 12"))
  end

  test "reads a slash date with a year" do
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("lunch 12 9/26/2026"))
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: nil, occurred_on: Date.new(2025, 9, 26), dated: true, errors: [] },
      read("lunch 12 9/26/25"))
  end

  test "keeps a written-out date outside the last 20 years and the next year in the name" do
    assert_equal({ name: "lunch 2062-09-26", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("lunch 12 2062-09-26"))
    assert_equal({ name: "lunch 9/26/1990", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("lunch 12 9/26/1990"))
    assert_equal({ name: "feb 30 2026 rent", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("feb 30 2026 rent 12"))
  end

  test "reads an ISO date as written" do
    assert_equal({ name: "lunch", amount_in_cents: -1200, category_word: nil, occurred_on: Date.new(2026, 9, 20), dated: true, errors: [] },
      read("lunch 12 2026-09-20"))
  end

  test "leaves an impossible month name and day in the name" do
    assert_equal({ name: "feb 30 thing", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("feb 30 thing 5"))
  end

  test "leaves an impossible slash date in the name" do
    assert_equal({ name: "13/40 thing", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("13/40 thing 5"))
  end

  test "takes only the first date" do
    assert_equal({ name: "lunch yesterday", amount_in_cents: -1200, category_word: nil, occurred_on: Date.new(2026, 9, 20), dated: true, errors: [] },
      read("lunch yesterday 12 2026-09-20"))
  end

  test "joins the remaining words with single spaces and keeps their case" do
    assert_equal({ name: "Blue Bottle", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("  Blue   Bottle 5  "))
  end

  test "asks for an amount when there is none" do
    assert_equal({ name: "coffee", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50" ] },
      read("coffee"))
  end

  test "asks for a name when no words remain" do
    assert_equal({ name: "", amount_in_cents: -550, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type a name, like coffee" ] },
      read("5.50"))
  end

  test "asks for both on blank shorthand" do
    assert_equal({ name: "", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50", "Type a name, like coffee" ] },
      read("   "))
  end

  test "skips a zero amount and keeps it in the name" do
    assert_equal({ name: "coffee 0.00", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50" ] },
      read("coffee 0.00"))
    assert_equal({ name: "coffee 0", amount_in_cents: -500, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("coffee 0 5"))
  end

  test "splits on any whitespace" do
    assert_equal({ name: "coffee", amount_in_cents: -500, category_word: nil, occurred_on: Date.new(2026, 9, 26), dated: true, errors: [] },
      read("coffee\u00a05\tyesterday"))
  end

  test "keeps malformed amounts in the name" do
    assert_equal({ name: "5.5.5 thing", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50" ] },
      read("5.5.5 thing"))
    assert_equal({ name: "$ coffee", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50" ] },
      read("$ coffee"))
    assert_equal({ name: "car 12345678", amount_in_cents: nil, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [ "Type an amount, like 5.50" ] },
      read("car 12345678"))
  end

  test "reads every date the calendar writes after an at sign" do
    assert_equal [ SUNDAY, Date.new(2026, 9, 26), Date.new(2026, 8, 27), Date.new(2025, 12, 31), Date.new(2026, 9, 25), Date.new(2026, 9, 20) ],
      [ "Lyft 9 @today", "Lyft 9 @yesterday", "Lyft 9 @aug 27", "Lyft 9 @dec 31 2025", "Lyft 9 @friday", "Lyft 9 @2026-09-20" ].map { |shorthand| read(shorthand)[:occurred_on] }
    assert_equal "Lyft", read("Lyft 9 @aug 27")[:name]
  end

  test "takes a bare at sign out of the name and keeps one before other words" do
    assert_equal({ name: "lunch @work", amount_in_cents: -1200, category_word: nil, occurred_on: SUNDAY, dated: false, errors: [] },
      read("lunch @work 12 @"))
  end

  test "marks where the amount, date, and category sit in the typed text" do
    tokens = Transaction::Shorthand.read("Blue  Bottle 5.50 @sep 26 #food #", today: SUNDAY).tokens

    assert_equal [ [ :amount, 13, 17 ], [ :date, 18, 25 ], [ :category, 26, 31 ], [ :category, 32, 33 ] ],
      tokens.map { |token| [ token.kind, token.start, token.finish ] }
  end

  test "marks nothing a word stays in the name for" do
    assert_empty Transaction::Shorthand.read("feb 30 thing", today: SUNDAY).tokens
  end

  test "aims at the date a complete fragment reads as" do
    assert_equal [ Date.new(2026, 9, 26), Date.new(2025, 9, 26), Date.new(2025, 9, 26), Date.new(2025, 9, 26), SUNDAY, Date.new(2026, 9, 26), Date.new(2026, 9, 21) ],
      [ "9/26", "9/26/25", "2025-09-26", "sep 26 2025", "today", "yesterday", "monday" ].map { |fragment| aim(fragment).on }
    assert_predicate aim("sep 26 2025"), :exact
  end

  test "aims at the latest past month for a month number or name" do
    assert_equal [ Date.new(2026, 9, 27), Date.new(2025, 12, 27), Date.new(2026, 5, 27), Date.new(2025, 11, 27), Date.new(2026, 9, 27), Date.new(2025, 12, 27) ],
      [ "9", "12/", "may", "no", "se", "dec " ].map { |fragment| aim(fragment).on }
    assert_equal Date.new(2026, 2, 28), aim("2", today: Date.new(2026, 3, 31)).on
    assert_equal Date.new(2025, 2, 28), aim("feb", today: Date.new(2026, 1, 31)).on
    assert_not aim("9").exact
  end

  test "aims at the latest past day for a month and day with a year in progress" do
    assert_equal [ Date.new(2026, 9, 26) ] * 5 + [ Date.new(2026, 9, 21) ],
      [ "9/26/", "9/26/2", "9/26/202", "sep 26 ", "sep 26 20", "sep 21 202" ].map { |fragment| aim(fragment).on }
    assert_equal Date.new(2025, 9, 26), aim("9/26/", today: Date.new(2026, 9, 20)).on
    assert_equal Date.new(2024, 2, 29), aim("2/29/").on
    assert_not aim("9/26/").exact
  end

  test "aims at the start of a year or month for an ISO date in progress" do
    assert_equal [ Date.new(2024, 1, 27), Date.new(2024, 1, 27), SUNDAY, Date.new(2024, 3, 27), Date.new(2024, 3, 27), Date.new(2024, 3, 27), SUNDAY ],
      [ "2024", "2024-", "2026", "2024-03", "2024-03-", "2024-3", "2026-12" ].map { |fragment| aim(fragment).on }
    assert_not aim("2024").exact
    assert_equal Aim.new(on: Date.new(2024, 3, 1), exact: true), aim("2024-03-1")
  end

  test "aims at a day word's date while it is typed" do
    assert_equal [ SUNDAY, Date.new(2026, 9, 26), Date.new(2026, 9, 21), Date.new(2026, 9, 26) ],
      [ "tod", "yest", "mon", "sa" ].map { |fragment| aim(fragment).on }
    assert_not aim("yest").exact
  end

  test "lets a day word win a letter a month name shares" do
    assert_equal Date.new(2026, 9, 26), aim("s").on
    assert_equal Date.new(2026, 9, 27), aim("se").on
  end

  test "aims nowhere for a start that could still become a date" do
    assert_equal Aim.new(on: nil, exact: false), aim("202")
    assert_equal Aim.new(on: nil, exact: false), aim("20")
    assert_equal Aim.new(on: nil, exact: false), aim("0")
  end

  test "has no aim for what cannot become a date" do
    [ "13/40", "abc1", "13", "2/30/", "1990", "2024-13", "2024-03-40", "sep 31", "sep 26 20300", "5.50", "sepx", "9/26/1999" ].each do |fragment|
      assert_nil aim(fragment), fragment
    end
  end

  test "keeps aims inside the twenty years back and never after today" do
    assert_equal Date.new(2007, 1, 27), aim("2007").on
    assert_nil aim("2006")
    assert_nil aim("2005")
    assert_equal SUNDAY, aim("2027").on
  end

  private
    def aim(fragment, today: SUNDAY)
      Transaction::Shorthand.aim(fragment, today:)
    end

    def read(shorthand, today: SUNDAY)
      Transaction::Shorthand.read(shorthand, today:).to_h.except(:tokens)
    end
end
