require "test_helper"

class VoucherTest < ActiveSupport::TestCase
  SUNDAY = Date.new(2026, 9, 27)

  test "returns the attributes a transaction saves" do
    assert_equal({ name: "coffee", amount_in_cents: -550, occurred_on: Date.new(2026, 9, 26), category: nil, shorthand: "coffee 5.50 yesterday" },
      build("coffee 5.50 yesterday").attributes)
  end

  test "matches a hash word to an existing category ignoring case" do
    voucher = build("lunch 12 #FOOD")

    assert_equal categories(:food), voucher.category
    assert_not voucher.inferred?
  end

  test "builds an unsaved category for a new hash word" do
    category = build("taxi 30 #travel").category

    assert_equal [ "travel", users(:one), true ], [ category.name, category.user, category.new_record? ]
  end

  test "matches a hash word only among the user's own categories" do
    category = build("lunch 12 #food", user: users(:two)).category

    assert_equal [ "food", users(:two), true ], [ category.name, category.user, category.new_record? ]
  end

  test "infers the category from the same name ignoring case" do
    voucher = build("BLUE BOTTLE 6")

    assert_equal [ categories(:food), true ], [ voucher.category, voucher.inferred? ]
  end

  test "infers from the latest transaction, or the one before it when that is being edited" do
    cafe = users(:one).categories.create!(name: "Cafe")
    newer = users(:one).transactions.create!(name: "Blue Bottle", amount_in_cents: -600, occurred_on: "2026-10-02", category: cafe)

    assert_equal "Cafe", build("blue bottle 6").category_name
    assert_equal "Food", build("blue bottle 6", editing: newer).category_name
  end

  test "infers the category for shorthand ending in a bare hash" do
    voucher = build("Blue Bottle 6 #")

    assert_equal [ "Blue Bottle", categories(:food), true ], [ voucher.name, voucher.category, voucher.inferred? ]
  end

  test "infers only from the same user's kept transactions" do
    assert_nil build("blue bottle 6", user: users(:two)).category

    transactions(:coffee).discard
    assert_nil build("blue bottle 6").category
  end

  test "leaves the edited row out of inference" do
    assert_nil build("blue bottle 6", editing: transactions(:coffee)).category
  end

  test "infers the category for shorthand still missing its amount" do
    voucher = build("blue bottle")

    assert_equal [ categories(:food), false, [ "Type an amount, like 5.50" ] ], [ voucher.category, voucher.valid?, voucher.errors ]
  end

  test "skips the category lookup when the shorthand has no name" do
    user = users(:one)

    assert_queries_count(0) { assert_nil build("5.50", user:).category }
  end

  test "is dated only when the shorthand names a date" do
    assert_equal [ false, true, true, true ],
      [ "coffee 5", "coffee 5 yesterday", "coffee 5 sep 24", "coffee 5 9/24" ].map { |shorthand| build(shorthand).dated? }
  end

  test "reports money in" do
    voucher = build("+2000 paycheck")

    assert_equal [ true, true ], [ voucher.valid?, voucher.money_in? ]
    assert_not build("coffee 5").money_in?
  end

  test "runs no query until asked for its category or completion" do
    user = users(:one)

    assert_no_queries { Voucher.new("blue bottle 6", user:, today: SUNDAY, complete: true) }
  end

  test "never writes and reads with at most one query" do
    user = users(:one)

    assert_no_difference [ "Transaction.count", "Category.count" ] do
      assert_queries_count(1) { Voucher.new("taxi 30 #travel", user:, today: SUNDAY).category }
      assert_queries_count(1) { Voucher.new("blue bottle 6", user:, today: SUNDAY).category }
    end
    assert_equal [ "Food" ], user.categories.map(&:name)
  end

  test "completes a typed prefix with the most used kept name in its stored spelling and takes its category" do
    groceries = users(:one).categories.create!(name: "Groceries")
    add "Trader Joe's", "2026-09-01", groceries
    add "Trader Joe's", "2026-09-02", groceries
    add "Trader Vic's", "2026-09-20"

    voucher = complete("tra")
    assert_equal [ "Trader Joe's", "Groceries", [ "Type an amount, like 5.50" ] ], [ voucher.completion, voucher.category_name, voucher.errors ]
  end

  test "breaks a tie in use count with the latest occurred_on" do
    add "Trader Joe's", "2026-09-01"
    add "Trader Vic's", "2026-09-20"

    assert_equal "Trader Vic's", complete("Tra").completion
  end

  test "offers only names longer than the typed shorthand" do
    add "Uber", "2026-09-01"
    add "Uber", "2026-09-02"
    add "Uber Eats", "2026-09-03"

    assert_equal "Uber Eats", complete("Uber").completion
    assert_nil complete("Uber Eats").completion
  end

  test "never offers a discarded name or another user's name" do
    add("Lyft", "2026-09-01").discard
    users(:two).transactions.create!(name: "Lyme Farm", amount_in_cents: -100, occurred_on: "2026-09-01")

    assert_nil complete("Ly").completion
  end

  test "completes only shorthand of two or more letters without amount, date, or category marks" do
    add "B2 Cafe", "2026-09-01"

    assert_equal [ nil, nil, nil, nil, nil, "Blue Bottle", nil ],
      [ "B", "B2", "Blue #", "Blue @", "Blue $", "  Bl", "Blue Bottle 5" ].map { |shorthand| complete(shorthand).completion }
    assert_nil build("Bl").completion
  end

  test "treats LIKE wildcards in the shorthand as text" do
    add "50% off", "2026-09-01"
    add "5_star", "2026-09-01"

    assert_nil complete("%o").completion
    assert_nil complete("__").completion
  end

  private
    def build(shorthand, user: users(:one), editing: nil)
      Voucher.new(shorthand, user:, today: SUNDAY, editing:)
    end

    def complete(shorthand)
      Voucher.new(shorthand, user: users(:one), today: SUNDAY, complete: true)
    end

    def add(name, occurred_on, category = nil)
      users(:one).transactions.create!(name:, amount_in_cents: -100, occurred_on:, category:)
    end
end
