require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a new user starts with the Income category" do
    user = User.create!(username: "new", password: "password")

    assert_equal [ [ "Income", true ] ], user.categories.pluck(:name, :income)
    assert_equal user.categories.first, user.income_category
  end

  test "the oldest user is the owner and registration starts closed" do
    assert_equal users(:one), User.owner
    assert users(:one).owner?
    assert_not users(:two).owner?
    assert_not User.registration_open?
  end

  test "registration follows the owner's choice and passes on when the owner is deleted" do
    users(:one).open_registration(true)
    assert User.registration_open?

    Transaction.delete_all
    users(:one).destroy
    assert users(:two).owner?
    assert_not User.registration_open?
  end

  test "registration is open when no one has an account" do
    Transaction.delete_all
    User.destroy_all

    assert_nil User.owner
    assert User.registration_open?
  end

  test "single-key shortcuts start on and follow the user's choice" do
    user = User.create!(username: "new", password: "password")
    assert user.single_key_shortcuts?

    user.use_single_key_shortcuts(false)
    assert_not user.reload.single_key_shortcuts?

    user.use_single_key_shortcuts(true)
    assert user.reload.single_key_shortcuts?
  end

  test "transactions hides a discarded row" do
    user = users(:one)
    transactions(:coffee).discard

    assert_equal [ "Paycheck" ], user.transactions.pluck(:name)
  end

  test "starting an import replaces the draft in progress" do
    user = users(:one)
    first = user.start_import(import_file("personal.csv"))
    second = user.start_import(import_file("bank.csv"))

    assert_equal [ false, [ second ] ], [ Import.exists?(first.id), user.imports.drafts.to_a ]
  end

  test "a file it can't read leaves the draft in progress alone" do
    user = users(:one)
    draft = user.start_import(import_file("personal.csv"))
    failed = user.start_import(upload("receipt.pdf", "%PDF"))

    assert_equal [ false, [ "Choose an Excel (.xlsx) or CSV file." ], [ draft ] ], [ failed.persisted?, failed.errors[:file], user.imports.drafts.to_a ]
  end

  test "starting an import keeps the ones already done, and the latest is the last completed" do
    user = users(:one)
    travel_to(Time.utc(2026, 10, 1)) { user.start_import(import_file("day_first.csv")).complete }
    travel_to(Time.utc(2026, 10, 2)) { user.start_import(import_file("bank.csv")).complete }
    user.start_import(import_file("personal.csv"))

    assert_equal [ "bank.csv", 3 ], [ user.latest_import.filename, user.imports.count ]
  end

  test "a new user has seen the version they signed up on" do
    user = User.create!(username: "new", password: "password")

    assert_equal [ Release.current_version, [] ], [ user.seen_version, user.unseen_releases ]
  end

  test "a user on an older version has unseen releases, newest first" do
    user = users(:one)
    user.update!(seen_version: "0.5.0")

    assert_equal [ Release.current_version, "0.6.0" ], [ user.unseen_releases.first.version, user.unseen_releases.last.version ]
  end

  test "seeing the releases clears them" do
    user = users(:one)
    user.update!(seen_version: "0.5.0")

    user.see_releases

    assert_equal [ Release.current_version, [] ], [ user.reload.seen_version, user.unseen_releases ]
  end

  test "resetting a password signs the user out everywhere" do
    user = users(:two)
    user.sessions.create!

    assert user.reset_password("new-secret", "new-secret")

    assert user.reload.authenticate("new-secret")
    assert_empty user.sessions
  end

  test "a mismatched or blank reset keeps the password and the sessions" do
    user = users(:two)
    user.sessions.create!

    assert_not user.reset_password("new-secret", "other")
    assert_not user.reset_password("", "")

    assert user.reload.authenticate("password")
    assert_equal 1, user.sessions.count
  end

  test "a reset token works once and then for a day at most" do
    user = users(:two)
    token = user.password_reset_token

    assert_equal user, User.find_by_password_reset_token(token)
    user.reset_password("new-secret", "new-secret")
    assert_nil User.find_by_password_reset_token(token)

    fresh = user.password_reset_token
    travel 25.hours
    assert_nil User.find_by_password_reset_token(fresh)
  end
end
