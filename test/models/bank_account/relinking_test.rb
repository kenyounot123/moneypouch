require "test_helper"

class BankAccount::RelinkingTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    @access = connect_simplefin
    activate(@access)
    @savings = @access.bank_accounts.find_by!(external_id: "Demo Savings")
    travel 1.hour
  end

  test "an account SimpleFIN stops sending is missing until it comes back" do
    without_savings = simplefin_report
    without_savings["accounts"].delete(demo_account(without_savings, "Demo Savings"))

    sync_again(@access, report: without_savings)
    assert @savings.reload.missing?
    assert_not @access.bank_accounts.find_by!(external_id: "Demo Checking").missing?

    sync_again(@access)
    assert_not @savings.reload.missing?
  end

  test "a sync that fails marks nothing missing" do
    stub_simplefin_accounts(status: 500, body: "")
    perform_enqueued_jobs { @access.sync_later }

    assert_not @savings.reload.missing?
  end

  test "a skipped account SimpleFIN stops sending is not missing" do
    empty = @access.bank_accounts.find_by!(external_id: "Demo Empty Account")
    without_empty = simplefin_report
    without_empty["accounts"].delete(demo_account(without_empty, "Demo Empty Account"))

    sync_again(@access, report: without_empty)

    assert empty.reload.skipped?
    assert_not empty.missing?
  end

  test "the account SimpleFIN sends under a new id is the replacement" do
    sync_again(@access, report: relinked_report)

    assert_equal "Relinked Demo Savings", @savings.reload.replacement.external_id
  end

  test "an account that is not missing has no replacement" do
    report = simplefin_report
    report["accounts"] << demo_account(report, "Demo Savings").merge("id" => "Second Savings")

    sync_again(@access, report:)

    assert_nil @savings.reload.replacement
  end

  test "two accounts with the missing one's name leave no replacement" do
    report = relinked_report
    report["accounts"] << demo_account(report, "Relinked Demo Savings").merge("id" => "Second Savings")

    sync_again(@access, report:)

    assert_nil @savings.reload.replacement
  end

  test "an account with the same name at another bank is not a replacement" do
    report = relinked_report
    report["connections"] = [ *report["connections"], { "conn_id" => "CON-OTHER", "org_name" => "Other Bank" } ]
    demo_account(report, "Relinked Demo Savings")["conn_id"] = "CON-OTHER"

    sync_again(@access, report:)

    assert_nil @savings.reload.replacement
  end

  test "carrying on keeps the history once and adds only what is new" do
    report = relinked_report
    sync_again(@access, report:)
    demo_account(report, "Relinked Demo Savings")["transactions"] << bought("new-purchase", "-20.00", Time.utc(2026, 10, 5, 18))

    assert_difference -> { Transaction.count } => 1, -> { @savings.bank_transactions.count } => 1 do
      carry_on(report)
    end
    assert_equal [ -2000 ], @access.syncs.last.bank_transactions.pluck(:amount_in_cents)
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
    assert_not @savings.missing?
    assert_equal 1, @access.bank_accounts.where(name: @savings.name).count
  end

  test "a purchase on the last known day that posts after the relink still arrives" do
    report = relinked_report
    sync_again(@access, report:)
    last_day = @savings.bank_transactions.maximum(:occurred_on)
    demo_account(report, "Relinked Demo Savings")["transactions"] << bought("late", "-31.00", last_day.in_time_zone("America/Los_Angeles") + 20.hours)

    carry_on(report)

    assert_equal [ -3100 ], @access.syncs.last.bank_transactions.pluck(:amount_in_cents)
  end

  test "history that arrives over several syncs is not added again" do
    sync_again(@access, report: relinked_report)
    first_part = relinked_report
    demo_account(first_part, "Relinked Demo Savings")["transactions"].pop(3)

    assert_no_difference -> { Transaction.count } do
      carry_on(first_part)
      sync_again(@access, report: relinked_report)
    end
  end

  test "two equal purchases keep both, and a third one is added" do
    report = simplefin_report
    coffee = bought("twin-1", "-4.00", Time.utc(2026, 10, 4, 18))
    demo_account(report, "Demo Savings")["transactions"].push(coffee, coffee.merge("id" => "twin-2"))
    sync_again(@access, report:)
    travel 1.hour

    report = relinked_report(report)
    sync_again(@access, report:)
    demo_account(report, "Relinked Demo Savings")["transactions"] << coffee.merge("id" => "twin-3")

    assert_difference -> { Transaction.count } => 1 do
      carry_on(report)
    end
    assert_equal 3, @savings.bank_transactions.where(amount_in_cents: -400).count
  end

  test "a row the user discarded stays discarded" do
    grocery = @savings.transactions.kept.first
    grocery.discard
    sync_again(@access, report: relinked_report)

    assert_no_difference -> { Transaction.count } do
      carry_on(relinked_report)
    end
    assert grocery.reload.discarded_at.present?
  end

  test "carrying on keeps what the new account already brought in" do
    report = relinked_report
    sync_again(@access, report:)
    demo_account(report, "Relinked Demo Savings")["transactions"] << bought("new-purchase", "-20.00", Time.utc(2026, 10, 5, 18))
    @savings.reload.replacement.start_syncing(from: Date.new(2026, 10, 5))
    sync_again(@access, report:)

    assert_no_difference -> { Transaction.count } do
      carry_on(report)
    end
    assert @savings.bank_transactions.find_by!(external_id: "new-purchase").unmatched?
  end

  test "carrying on twice changes nothing more" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)

    assert_no_difference -> { BankAccount.count } do
      carry_on(relinked_report)
    end
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
  end

  test "two clicks that loaded the account before either finished keep its rows" do
    sync_again(@access, report: relinked_report)
    clicks = Array.new(2) { BankAccount.find(@savings.id) }
    stub_simplefin_accounts(body: relinked_report.to_json)

    assert_no_difference -> { BankTransaction.count } do
      clicks.each(&:carry_on_with_replacement)
    end
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
  end

  test "two missing accounts with one name leave no replacement" do
    report = simplefin_report
    report["accounts"] << demo_account(report, "Demo Savings").merge("id" => "Twin Savings")
    sync_again(@access, report:)
    twin = @access.bank_accounts.find_by!(external_id: "Twin Savings")
    twin.start_syncing(from: Date.new(2026, 7, 9))
    sync_again(@access, report:)
    travel 1.hour

    sync_again(@access, report: relinked_report)
    assert_equal [ nil, nil ], [ @savings.reload.replacement, twin.reload.replacement ]

    twin.skip
    assert_equal "Relinked Demo Savings", @savings.reload.replacement.external_id
  end

  test "a namesake SimpleFIN once sent beside the missing account is not its replacement" do
    report = simplefin_report
    report["accounts"] << demo_account(report, "Demo Savings").merge("id" => "Newer Savings")
    sync_again(@access, report:)
    travel 1.hour
    report["accounts"].delete(demo_account(report, "Demo Savings"))

    sync_again(@access, report:)
    assert @savings.reload.missing?
    assert_nil @savings.replacement

    @access.bank_accounts.find_by!(external_id: "Newer Savings").start_syncing(from: Date.new(2026, 10, 6))
    assert_nil @savings.replacement
  end

  test "a second relink before the first is confirmed offers the account SimpleFIN sends now" do
    sync_again(@access, report: relinked_report)
    travel 1.hour
    again = relinked_report
    demo_account(again, "Relinked Demo Savings")["id"] = "Relinked twice"

    sync_again(@access, report: again)

    assert_equal "Relinked twice", @savings.reload.replacement.external_id
  end

  test "an account relinked twice keeps its history once" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour
    again = relinked_report
    demo_account(again, "Relinked Demo Savings").then do |savings|
      savings["id"] = "Relinked twice"
      savings["transactions"].each { |transaction| transaction["id"] = "again-#{transaction["id"]}" }
    end
    sync_again(@access, report: again)

    assert_no_difference -> { Transaction.count } do
      carry_on(again)
    end
    assert_equal "Relinked twice", @savings.reload.external_id
  end

  test "an equal purchase on an account that was never relinked is added" do
    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << bought("first", "-4.00", Time.utc(2026, 10, 4, 18))
    sync_again(@access, report:)
    demo_account(report, "Demo Savings")["transactions"].last["id"] = "second"

    assert_difference -> { @savings.bank_transactions.where(amount_in_cents: -400).count } => 1 do
      sync_again(@access, report:)
    end
  end

  test "Same account after Sync it on the new account keeps one row per transaction" do
    sync_again(@access, report: relinked_report)
    sync_it(@savings.reload.replacement, relinked_report)

    assert_difference -> { Transaction.count } => -5 do
      carry_on(relinked_report)
    end
    assert_equal relinked_ids, @savings.bank_transactions.pluck(:external_id).sort
  end

  test "Same account when the bank changed only the account id keeps one row per transaction" do
    report = simplefin_report
    demo_account(report, "Demo Savings")["id"] = "Relinked Demo Savings"
    sync_again(@access, report:)
    sync_it(@savings.reload.replacement, report)

    assert_difference -> { Transaction.count } => -5 do
      carry_on(report)
    end
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
    assert_equal 5, @savings.bank_transactions.count
  end

  test "the copy you kept stays, with its category, when you deleted the other by hand" do
    sync_again(@access, report: relinked_report)
    replacement = @savings.reload.replacement
    sync_it(replacement, relinked_report)
    old_copy = @savings.transactions.find_by!(amount_in_cents: -13550)
    new_copy = replacement.transactions.find_by!(amount_in_cents: -13550)
    old_copy.discard
    new_copy.categorize(Transaction::Categorization.new(category: users(:one).categories.create!(name: "Bikes")))

    carry_on(relinked_report)

    assert_equal 5, @savings.transactions.kept.count
    assert_equal "Bikes", @savings.transactions.kept.find_by!(amount_in_cents: -13550).category.name
  end

  test "Same account after Sync it, run twice, changes nothing more" do
    sync_again(@access, report: relinked_report)
    sync_it(@savings.reload.replacement, relinked_report)
    carry_on(relinked_report)

    assert_no_difference [ -> { Transaction.count }, -> { BankTransaction.count }, -> { BankAccount.count } ] do
      carry_on(relinked_report)
      sync_again(@access, report: relinked_report)
    end
  end

  test "a time zone change before Same account keeps a late-night purchase once" do
    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << bought("late", "-12.00", Time.utc(2026, 10, 5, 6, 30))
    sync_again(@access, report:)
    users(:one).update!(time_zone: "America/New_York")
    travel 1.hour
    report = relinked_report(report)
    sync_again(@access, report:)

    assert_no_difference -> { Transaction.count } do
      carry_on(report)
    end
    assert_equal 6, @savings.bank_transactions.count
  end

  test "rows stored before posted times were kept carry on after a time zone change" do
    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << bought("late", "-12.00", Time.utc(2026, 10, 5, 6, 30))
    sync_again(@access, report:)
    BankTransaction.update_all(posted_at: nil)
    sync_again(@access, report:)
    users(:one).update!(time_zone: "America/New_York")
    travel 1.hour
    report = relinked_report(report)
    sync_again(@access, report:)

    assert_no_difference -> { Transaction.count } do
      carry_on(report)
    end
  end

  private
    def sync_it(bank_account, report)
      stub_simplefin_accounts(body: report.to_json)
      perform_enqueued_jobs { bank_account.sync_recent_history }
    end

    def relinked_ids
      demo_account(relinked_report, "Relinked Demo Savings")["transactions"].pluck("id").sort
    end

    def carry_on(report)
      stub_simplefin_accounts(body: report.to_json)
      perform_enqueued_jobs { BankAccount.find(@savings.id).carry_on_with_replacement }
    end

    def bought(id, amount, time)
      { "id" => id, "posted" => time.to_i, "transacted_at" => time.to_i, "amount" => amount, "description" => "Bike shop" }
    end
end
