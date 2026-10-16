require "test_helper"

class UserTest < ActiveSupport::TestCase
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
end
