require "test_helper"

class User::GetStartedTest < ActiveSupport::TestCase
  include SimplefinTestHelper

  setup do
    @user = User.create!(username: "newcomer", password: "password")
  end

  test "a new user has all three steps to do" do
    get_started = @user.get_started

    assert_equal [ :add, :categorize, :bring_in_history ], get_started.steps.map(&:name)
    assert_equal [ false, false, false ], get_started.steps.map(&:done?)
    assert_equal 0, get_started.done_count
    assert_predicate get_started, :pending?
  end

  test "adding a transaction finishes the first step only" do
    @user.transactions.create!(name: "Chipotle", amount_in_cents: -1125, occurred_on: Date.current)

    assert_equal [ true, false, false ], @user.get_started.steps.map(&:done?)
    assert_equal 1, @user.get_started.done_count
  end

  test "a transaction deleted again does not count as added" do
    @user.transactions.create!(name: "Chipotle", amount_in_cents: -1125, occurred_on: Date.current).discard

    assert_equal [ false, false, false ], @user.get_started.steps.map(&:done?)
  end

  test "giving a transaction a category finishes the second step" do
    transaction = @user.transactions.create!(name: "Chipotle", amount_in_cents: -1125, occurred_on: Date.current)
    transaction.categorize_as(category: "Food", transfer: false)

    assert_equal [ true, true, false ], @user.get_started.steps.map(&:done?)
  end

  test "a completed import finishes the third step, a draft does not, and the rows it brings count too" do
    import = @user.imports.create!(file: upload("history.csv", "Date,Item,Category,Amount\n2024-10-04,Trader Joe's,Groceries,42.10\n"))
    assert_not_predicate @user.get_started.steps.last, :done?

    import.complete

    assert_equal [ true, true, true ], @user.get_started.steps.map(&:done?)
  end

  test "a bank account that syncs finishes the third step, one that is only found does not" do
    access = connect_simplefin(@user)
    assert_equal [ false, false, false ], @user.get_started.steps.map(&:done?)

    access.bank_accounts.first.start_syncing(from: Date.current)

    assert_equal [ false, false, true ], @user.get_started.steps.map(&:done?)
  end

  test "nothing is pending once every step is done" do
    @user.transactions.create!(name: "Chipotle", amount_in_cents: -1125, occurred_on: Date.current).categorize_as(category: "Food", transfer: false)
    @user.imports.create!(file: upload("history.csv", "Date,Item,Category,Amount\n2024-10-04,Trader Joe's,Groceries,42.10\n")).complete

    assert_equal 3, @user.get_started.done_count
    assert_not_predicate @user.get_started, :pending?
  end

  test "hiding the list ends it however many steps are left" do
    @user.hide_get_started

    assert_equal 0, @user.get_started.done_count
    assert_not_predicate @user.get_started, :pending?
  end

  test "a new account shows the list and a sandbox starts with it hidden" do
    assert_not @user.get_started_hidden?
    assert_predicate User.create_sandbox, :get_started_hidden?
    assert_not_predicate User.create_sandbox.get_started, :pending?
  end
end
