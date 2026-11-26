require "test_helper"

class BankAccount::RelinkingTest < ActiveSupport::TestCase
  ONE_POSTING_A_DAY = Time.utc(2026, 10, 5, 12)

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

  test "an empty report marks nothing missing" do
    sync_again(@access, report: simplefin_report.merge("accounts" => []))

    assert_empty @access.bank_accounts.missing
  end

  test "a report with the old id that arrives after carrying on adds nothing" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour

    assert_no_difference -> { BankAccount.count } do
      assert_no_difference -> { BankTransaction.count } do
        sync_again(@access, report: simplefin_report)
      end
    end
    assert_not @savings.reload.missing?
  end

  test "a report that also sends the old id keeps what the new id sends" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour
    report = relinked_report
    report["accounts"] << demo_account(simplefin_report, "Demo Savings").merge("name" => "Old Savings", "balance" => "1.00")
    demo_account(report, "Demo Savings")["transactions"] << bought("old-only", "-9.99", Time.utc(2026, 10, 6, 18))

    assert_no_difference -> { BankTransaction.count } do
      sync_again(@access, report:)
    end
    assert_equal [ "Relinked Demo Savings", "SimpleFIN Savings", 11468551 ], [ @savings.reload.external_id, @savings.name, @savings.balance_in_cents ]
    assert_not @savings.missing?
  end

  test "a stale report with only the old id after Same account keeps the new id and its purchases" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour

    assert_no_difference -> { BankTransaction.count } do
      sync_again(@access, report: simplefin_report)
    end
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
    assert_not @savings.missing?

    travel 1.hour
    report = relinked_report
    demo_account(report, "Relinked Demo Savings")["transactions"] << bought("after-stale", "-8.08", Time.utc(2026, 10, 6, 20))
    report["accounts"] << demo_account(simplefin_report, "Demo Savings")

    assert_difference -> { @savings.bank_transactions.count } => 1 do
      sync_again(@access, report:)
      travel 1.hour
      sync_again(@access, report:)
    end
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
    assert_not @savings.missing?
  end

  test "a report that sends both ids takes the one with the newer balance" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour
    report = relinked_report
    report["accounts"] << demo_account(sent_later(simplefin_report), "Demo Savings").merge("name" => "Old Savings", "balance" => "1.00")
    demo_account(report, "Demo Savings")["transactions"] << bought("old-only", "-9.99", Time.utc(2026, 10, 6, 18))

    assert_difference -> { @savings.bank_transactions.count } => 1 do
      sync_again(@access, report:)
    end
    assert_equal [ "Demo Savings", "Old Savings", 100 ], [ @savings.reload.external_id, @savings.name, @savings.balance_in_cents ]
    assert_not @savings.missing?
  end

  test "a report that sends only the old id brings in its new purchases" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour
    report = sent_later(simplefin_report)
    demo_account(report, "Demo Savings")["transactions"] << bought("after-revert", "-9.99", Time.utc(2026, 10, 6, 18))

    assert_difference -> { Transaction.count } => 1, -> { @savings.bank_transactions.count } => 1 do
      sync_again(@access, report:)
    end
    assert_not @savings.reload.missing?
  end

  test "a report with the old id after Same account keeps one row per transaction when the new account lacked an old purchase" do
    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << bought("old-only", "-9.99", Time.utc(2026, 10, 5, 18))
    sync_again(@access, report:)
    travel 1.hour
    sync_it(synced_replacement, relinked_report)
    carry_on(relinked_report)
    travel 1.hour
    sent_later(report)

    assert_no_difference -> { BankTransaction.count } do
      sync_again(@access, report:)
    end
    assert_equal demo_account(report, "Demo Savings")["transactions"].pluck("id").sort, @savings.reload.bank_transactions.where(occurred_on: @access.history_start.to_date..).pluck(:external_id).sort
  end

  test "a purchase sent under the old id and then under the new one arrives once" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    travel 1.hour
    purchase = bought("late", "-9.99", Time.utc(2026, 10, 6, 18))
    under_old = ->(later) { sent_later(simplefin_report, by: later).tap { |report| demo_account(report, "Demo Savings")["transactions"] << purchase } }
    under_new = sent_later(relinked_report, "Relinked Demo Savings", by: 2.days)
    demo_account(under_new, "Relinked Demo Savings")["transactions"] << purchase.merge("id" => "relinked-late")

    assert_difference -> { Transaction.count } => 1 do
      sync_again(@access, report: under_old.(1.day))
      travel 1.hour
      sync_again(@access, report: under_new)
      travel 1.hour
      sync_again(@access, report: under_old.(3.days))
    end
    assert_equal 1, @savings.bank_transactions.where(amount_in_cents: -999).count
    assert_not @savings.reload.missing?
  end

  test "two people with the same SimpleFIN ids can each carry on" do
    sync_again(@access, report: relinked_report)
    carry_on(relinked_report)
    other_access = activate(connect_simplefin(users(:two)))
    other_savings = other_access.bank_accounts.find_by!(external_id: "Demo Savings")
    travel 1.hour
    sync_again(other_access, report: relinked_report)

    stub_simplefin_accounts(body: relinked_report.to_json)
    perform_enqueued_jobs { BankAccount.find(other_savings.id).carry_on_with_replacement }
    assert_equal "Relinked Demo Savings", other_savings.reload.external_id

    travel 1.hour
    report = sent_later(simplefin_report)
    demo_account(report, "Demo Savings")["transactions"] << bought("theirs", "-9.99", Time.utc(2026, 10, 6, 18))
    sync_again(other_access, report:)
    assert other_savings.bank_transactions.exists?(amount_in_cents: -999)
    assert_not @savings.bank_transactions.exists?(amount_in_cents: -999)
  end

  test "an account with no known last report offers no replacement" do
    sync_again(@access, report: relinked_report)
    @savings.reload.update_columns(reported_at: nil)

    assert_nil @savings.replacement
  end

  test "a renamed account can be matched with a new account from the same bank" do
    report = simplefin_report
    demo_account(report, "Demo Savings").merge!("id" => "Renamed Savings", "name" => "Premier Savings")
    sync_again(@access, report:)

    renamed = @access.bank_accounts.find_by!(external_id: "Renamed Savings")
    assert_nil @savings.reload.replacement
    assert_equal [ renamed ], @savings.replacement_choices.to_a

    perform_enqueued_jobs { BankAccount.find(@savings.id).carry_on_with_replacement(renamed.id) }

    assert_equal "Renamed Savings", @savings.reload.external_id
    assert_nil BankAccount.find_by(id: renamed.id)
  end

  test "carrying on with an account that is not a choice changes nothing" do
    sync_again(@access, report: relinked_report)
    other_bank = @access.bank_accounts.create!(external_id: "Elsewhere", name: "Elsewhere", institution: "Other Bank", currency: "USD")

    assert_no_difference -> { BankAccount.count } do
      @savings.reload.carry_on_with_replacement(other_bank.id)
    end
    assert @savings.reload.missing?
  end

  test "two missing accounts with one name each choose their own replacement" do
    report = simplefin_report
    report["accounts"] << demo_account(report, "Demo Savings").merge("id" => "Twin Savings")
    sync_again(@access, report:)
    twin = @access.bank_accounts.find_by!(external_id: "Twin Savings")
    twin.start_syncing(from: Date.new(2026, 7, 9))
    sync_again(@access, report:)
    travel 1.hour
    sync_again(@access, report: relinked_report)
    replacement = @access.bank_accounts.find_by!(external_id: "Relinked Demo Savings")

    assert_equal [ replacement ], twin.reload.replacement_choices.to_a
    perform_enqueued_jobs { BankAccount.find(twin.id).carry_on_with_replacement(replacement.id) }

    assert_equal "Relinked Demo Savings", twin.reload.external_id
    assert_empty @savings.reload.replacement_choices
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

  test "Same account after Sync it keeps a purchase at another shop with the same amount and posted time" do
    relinked = with_purchases(old: coffee("coffee-a", Time.utc(2026, 10, 5, 16)), new: coffee("coffee-b", Time.utc(2026, 10, 5, 16), description: "Starbucks"))
    sync_it(@savings.reload.replacement, relinked)

    carry_on(relinked)
    sync_again(@access, report: relinked)

    assert_equal [ "Blue Bottle", "Starbucks" ], @savings.transactions.kept.where(amount_in_cents: -400).pluck(:name).sort
  end

  test "another purchase at the same shop with the same amount on the same day arrives after Same account" do
    relinked = with_purchases(old: coffee("coffee-a", Time.utc(2026, 10, 5, 16)), new: coffee("coffee-b", Time.utc(2026, 10, 5, 22)))

    carry_on(relinked)
    sync_again(@access, report: relinked)

    assert_equal %w[ coffee-a coffee-b ], @savings.bank_transactions.where(amount_in_cents: -400).pluck(:external_id).sort
    assert_equal 2, @savings.transactions.kept.where(amount_in_cents: -400).count
  end

  test "the copy you kept wins over the one you deleted" do
    old_copy = @savings.transactions.find_by!(amount_in_cents: -13550)
    old_copy.categorize(Transaction::Categorization.new(category: users(:one).categories.create!(name: "Groceries")))
    old_copy.update!(note: "old note")
    old_copy.discard
    new_copy = synced_replacement.transactions.find_by!(amount_in_cents: -13550)
    new_copy.categorize(Transaction::Categorization.new(category: users(:one).categories.create!(name: "Bikes")))
    new_copy.update!(note: "new bike")
    new_copy.exclude

    carry_on(relinked_report)

    kept = @savings.transactions.kept.find_by!(amount_in_cents: -13550)
    assert_equal [ "Bikes", "new bike", false ], [ kept.category.name, kept.note, kept.counted? ]
  end

  test "a row you left out of totals counts when its other copy still counted" do
    @savings.transactions.find_by!(amount_in_cents: -13550).exclude
    synced_replacement

    carry_on(relinked_report)

    assert @savings.transactions.kept.find_by!(amount_in_cents: -13550).counted?
  end

  test "a transfer on the new copy moves to the row you keep" do
    @savings.transactions.find_by!(amount_in_cents: -13550).categorize(Transaction::Categorization.new(category: users(:one).categories.create!(name: "Groceries")))
    copy, partner = paired_copy

    carry_on(relinked_report)

    kept = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
    assert_equal [ partner, kept ], [ kept.transfer_partner, partner.reload.transfer_partner ]
    assert kept.linked_transaction.transfer?
    assert_not BankTransaction.exists?(copy.id)
  end

  test "a transfer on the new copy, when the row you keep is paired elsewhere, leaves its partner a plain row" do
    groceries = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
    other = @access.bank_accounts.find_by!(external_id: "Demo Checking").bank_transactions.find_by!(amount_in_cents: -17667)
    groceries.linked_transaction.update!(categorization: Transaction::Categorization.none)
    other.linked_transaction.update!(categorization: Transaction::Categorization.none)
    groceries.pair_with(other)
    _copy, partner = paired_copy

    carry_on(relinked_report)

    assert_equal other, groceries.reload.transfer_partner
    assert_not partner.reload.paired?
    assert_not partner.linked_transaction.transfer?
  end

  test "rows stored before posted times, on an account already missing, carry on after a time zone change" do
    relinked = missing_with_rows_before_posted_times(zone: "Pacific/Auckland")
    sync_it(@savings.reload.replacement, relinked)

    carry_on(relinked)
    2.times { sync_again(@access, report: relinked) }

    assert_equal 6, @savings.bank_transactions.count
    assert_equal 6, @savings.transactions.kept.count
  end

  test "rows stored before posted times, on an account already missing, are not added again by the sync after Same account" do
    relinked = missing_with_rows_before_posted_times(zone: "America/New_York")

    assert_no_difference -> { Transaction.count } do
      carry_on(relinked)
      sync_again(@access, report: relinked)
    end
  end

  test "a row stored before posted times with a possible copy on each side of its day keeps all three" do
    report = simplefin_report
    demo_account(report, "Demo Savings")["transactions"] << bought("lunch", "-9.00", Time.utc(2026, 10, 4, 20))
    sync_again(@access, report:)
    travel 1.hour
    relinked = relinked_report(report)
    demo_account(relinked, "Relinked Demo Savings")["transactions"].reject! { |transaction| transaction["id"] == "relinked-lunch" }
    demo_account(relinked, "Relinked Demo Savings")["transactions"].push(
      bought("lunch-before", "-9.00", Time.utc(2026, 10, 3, 20)), bought("lunch-after", "-9.00", Time.utc(2026, 10, 5, 20)))
    sync_again(@access, report: relinked)
    BankTransaction.update_all(posted_at: nil)
    sync_it(@savings.reload.replacement, relinked)

    carry_on(relinked)

    assert_equal 3, @savings.transactions.kept.where(amount_in_cents: -900).count
  end

  test "Same account after Sync it keeps a second coffee at the same shop when the bank posts a whole day at one time" do
    relinked = with_purchases(old: coffee("coffee-a", Time.utc(2026, 10, 5, 16), posted: ONE_POSTING_A_DAY), new: coffee("coffee-b", Time.utc(2026, 10, 5, 22), posted: ONE_POSTING_A_DAY))
    sync_it(@savings.reload.replacement, relinked)

    carry_on(relinked)
    sync_again(@access, report: relinked)

    assert_equal %w[ coffee-a coffee-b ], @savings.bank_transactions.where(amount_in_cents: -400).pluck(:external_id).sort
    assert_equal 2, @savings.transactions.kept.where(amount_in_cents: -400).count
  end

  test "a second coffee at the same shop arrives after Same account when the bank posts a whole day at one time" do
    relinked = with_purchases(old: coffee("coffee-a", Time.utc(2026, 10, 5, 16), posted: ONE_POSTING_A_DAY), new: coffee("coffee-b", Time.utc(2026, 10, 5, 22), posted: ONE_POSTING_A_DAY))

    carry_on(relinked)
    sync_again(@access, report: relinked)

    assert_equal %w[ coffee-a coffee-b ], @savings.bank_transactions.where(amount_in_cents: -400).pluck(:external_id).sort
    assert_equal 2, @savings.transactions.kept.where(amount_in_cents: -400).count
  end

  [ true, false ].each do |sync_first|
    test "a bank that kept its transaction ids keeps a second coffee with the same posted time and no purchase time apart (Sync it first: #{sync_first})" do
      same_ids = simplefin_report.tap { |report| demo_account(report, "Demo Savings")["id"] = "Relinked Demo Savings" }
      relinked = with_purchases(old: coffee("coffee-a", nil, posted: ONE_POSTING_A_DAY), new: coffee("coffee-b", nil, posted: ONE_POSTING_A_DAY), relinked: same_ids)
      sync_it(@savings.reload.replacement, relinked) if sync_first

      carry_on(relinked)
      sync_again(@access, report: relinked)

      assert_equal %w[ coffee-a coffee-b ], @savings.bank_transactions.where(amount_in_cents: -400).pluck(:external_id).sort
      assert_equal 7, @savings.transactions.kept.count
    end

    test "two coffees at one shop and posting time keep two rows when both copies arrive (Sync it first: #{sync_first})" do
      relinked_with_two_coffees(sync_first:)

      assert_equal 2, @savings.bank_transactions.where(amount_in_cents: -400).count
      assert_equal 2, @savings.transactions.kept.where(amount_in_cents: -400).count
    end

    test "a purchase the bank renamed at the relink leaves a duplicate and deletes nothing (Sync it first: #{sync_first})" do
      report = simplefin_report
      demo_account(report, "Demo Savings")["transactions"] << coffee("coffee-a", Time.utc(2026, 10, 5, 16), description: "SQ *BLUE BOTTLE 1234", posted: ONE_POSTING_A_DAY)
      sync_again(@access, report:)
      travel 1.hour
      relinked = relinked_report(report)
      demo_account(relinked, "Relinked Demo Savings")["transactions"].find { |transaction| transaction["id"] == "relinked-coffee-a" }["description"] = "Blue Bottle"
      sync_again(@access, report: relinked)
      sync_it(@savings.reload.replacement, relinked) if sync_first

      carry_on(relinked)
      sync_again(@access, report: relinked)

      assert_equal [ "Blue Bottle", "SQ *BLUE BOTTLE" ], @savings.transactions.kept.where(amount_in_cents: -400).pluck(:name).sort
      assert_equal 7, @savings.transactions.kept.count
    end

    test "Same account and the sync after it, run again, change nothing (Sync it first: #{sync_first})" do
      relinked = relinked_with_two_coffees(sync_first:)
      before = savings_rows

      sync_again(@access, report: relinked)
      carry_on(relinked)

      assert_equal before, savings_rows
    end
  end

  test "two coffees at one shop and posting time keep two rows when only one copy arrives" do
    relinked_with_two_coffees(sync_first: true, only_second: true)

    assert_equal 2, @savings.transactions.kept.where(amount_in_cents: -400).count
  end

  test "rows a day apart in a chain pair only where one copy fits" do
    old = ->(id, day) { BankTransaction.new(id:, amount_in_cents: -500, name_key: "coffee", occurred_on: Date.new(2026, 10, day)) }
    copy = ->(id, day) { BankTransaction.new(id:, amount_in_cents: -500, name_key: "coffee", occurred_on: Date.new(2026, 10, day), posted_at: Time.utc(2026, 10, day, 12)) }
    pairs = ->(olds, copies) { BankTransaction.pair_up(olds, copies).map { |pair| pair.map(&:id) } }

    assert_equal [], pairs.([ old[1, 1], old[3, 3] ], [ copy[10, 2] ])
    assert_equal [], pairs.([ old[2, 2] ], [ copy[10, 1], copy[11, 3] ])
    assert_equal [], pairs.([ old[1, 1], old[3, 3] ], [ copy[10, 2], copy[11, 4] ])
    assert_equal [ [ 2, 10 ] ], pairs.([ old[1, 1], old[2, 2] ], [ copy[10, 2], copy[11, 3] ])
    assert_equal [ [ 1, 10 ], [ 5, 11 ] ], pairs.([ old[1, 1], old[5, 5] ], [ copy[10, 2], copy[11, 6] ])
    assert_equal [ [ 2, 10 ], [ 3, 11 ] ], pairs.([ old[1, 1], old[2, 2], old[3, 3] ], [ copy[10, 2], copy[11, 3], copy[12, 4] ])
  end

  test "deleting the old copy of a transfer keeps the transfer on the copy you kept" do
    groceries = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
    partner = checking.bank_transactions.find_by!(amount_in_cents: -17667)
    [ groceries, partner ].each { |bank_transaction| bank_transaction.linked_transaction.update!(categorization: Transaction::Categorization.none) }
    groceries.pair_with(partner)
    synced_replacement
    groceries.linked_transaction.discard

    carry_on(relinked_report)

    kept = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
    assert_equal [ partner, kept ], [ kept.transfer_partner, partner.reload.transfer_partner ]
    assert kept.linked_transaction.kept?
    assert [ kept, partner ].all? { |bank_transaction| bank_transaction.linked_transaction.transfer? }
  end

  [ [ "Savings", "Checking" ], [ "Checking", "Savings" ] ].each do |order|
    test "a transfer between two relinked accounts stays one pair, confirming #{order.join(" then ")}" do
      relinked = relinked_report(relinked_report, external_id: "Demo Checking")
      groceries = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
      other = checking.bank_transactions.find_by!(amount_in_cents: -17667)
      pair_by_hand(groceries, other)
      new_savings, new_checking = relinked_and_synced([ @savings, checking ], relinked)
      pair_by_hand(new_savings.bank_transactions.find_by!(amount_in_cents: -13550), new_checking.bank_transactions.find_by!(amount_in_cents: -17667))

      order.each do |name|
        carry_on(relinked, name == "Savings" ? @savings : checking)
        assert_transfers_point_at_each_other
      end

      assert_equal other, groceries.reload.transfer_partner
    end
  end

  test "copies paired across two relinked accounts leave every transfer with a partner" do
    relinked = relinked_report(relinked_report, external_id: "Demo Checking")
    groceries = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
    other = checking.bank_transactions.find_by!(amount_in_cents: -17667)
    new_savings, new_checking = relinked_and_synced([ @savings, checking ], relinked)
    pair_by_hand(groceries, new_checking.bank_transactions.find_by!(amount_in_cents: -17667))
    pair_by_hand(new_savings.bank_transactions.find_by!(amount_in_cents: -13550), other)

    [ @savings, checking ].each do |account|
      carry_on(relinked, account)
      assert_transfers_point_at_each_other
    end

    assert_equal 10, @savings.bank_transactions.count + checking.bank_transactions.count
  end

  test "a purchase deleted on both copies stays deleted, and one left out of totals stays out when its copy was deleted" do
    groceries = @savings.transactions.find_by!(amount_in_cents: -13550)
    bait = @savings.transactions.find_by!(amount_in_cents: -550)
    replacement = synced_replacement
    groceries.discard
    replacement.transactions.find_by!(amount_in_cents: -13550).discard
    bait.exclude
    replacement.transactions.find_by!(amount_in_cents: -550).discard

    carry_on(relinked_report)

    assert_equal [ 0, 1 ], [ @savings.transactions.kept.where(amount_in_cents: -13550).count, @savings.transactions.where(amount_in_cents: -13550).count ]
    assert_not @savings.transactions.kept.find_by!(amount_in_cents: -550).counted?
  end

  test "a purchase posted months after the relink is added beside an old row from before the report's window" do
    relinked = with_old_row_left_in_doubt(bought("bike-jul10", "-25.00", Time.utc(2026, 7, 10, 18)))
    travel_to Time.utc(2026, 10, 28, 19)
    demo_account(relinked, "Relinked Demo Savings")["transactions"] << bought("late-bike", "-25.00", Time.utc(2026, 7, 11, 18), posted: Time.utc(2026, 10, 28, 12))

    sync_again(@access, report: relinked)

    assert_equal %w[ bike-jul10 late-bike ], @savings.bank_transactions.where(amount_in_cents: -2500).pluck(:external_id).sort
  end

  test "a purchase posted weeks after it was made is added beside an old row from the day before" do
    relinked = with_old_row_left_in_doubt(bought("bike-oct1", "-25.00", Time.utc(2026, 10, 1, 18)))
    travel_to Time.utc(2026, 10, 28, 19)
    demo_account(relinked, "Relinked Demo Savings")["transactions"] << bought("late-bike", "-25.00", Time.utc(2026, 10, 2, 18), posted: Time.utc(2026, 10, 28, 12))

    sync_again(@access, report: relinked)

    assert_equal %w[ bike-oct1 late-bike ], @savings.bank_transactions.where(amount_in_cents: -2500).pluck(:external_id).sort
  end

  test "the copy you kept keeps its category when the old copy's transfer partner was deleted too" do
    groceries = users(:one).categories.create!(name: "Groceries")
    old = @savings.bank_transactions.find_by!(amount_in_cents: -13550)
    partner = checking.bank_transactions.find_by!(amount_in_cents: -17667)
    pair_by_hand(old, partner)
    synced_replacement.transactions.find_by!(amount_in_cents: -13550).categorize(Transaction::Categorization.new(category: groceries))
    partner.linked_transaction.discard
    old.linked_transaction.discard

    carry_on(relinked_report)

    assert_equal groceries, @savings.transactions.kept.find_by!(amount_in_cents: -13550).category
    assert_transfers_point_at_each_other
  end

  private
    def with_purchases(old:, new:, relinked: relinked_report)
      report = simplefin_report
      demo_account(report, "Demo Savings")["transactions"] << old
      sync_again(@access, report:)
      travel 1.hour
      relinked.tap do
        demo_account(relinked, "Relinked Demo Savings")["transactions"] << new
        sync_again(@access, report: relinked)
      end
    end

    def with_old_row_left_in_doubt(row)
      report = simplefin_report
      demo_account(report, "Demo Savings")["transactions"] << row
      sync_again(@access, report:)
      BankTransaction.update_all(posted_at: nil, transacted_at: nil)
      travel_to Time.utc(2026, 10, 16, 19)
      relinked_report(simplefin_report).tap do |relinked|
        sync_again(@access, report: relinked)
        carry_on(relinked)
      end
    end

    def relinked_with_two_coffees(sync_first:, only_second: false)
      report = simplefin_report
      demo_account(report, "Demo Savings")["transactions"].push(
        coffee("coffee-1", Time.utc(2026, 10, 5, 16), posted: ONE_POSTING_A_DAY), coffee("coffee-2", Time.utc(2026, 10, 5, 20), posted: ONE_POSTING_A_DAY))
      sync_again(@access, report:)
      travel 1.hour
      relinked_report(report).tap do |relinked|
        demo_account(relinked, "Relinked Demo Savings")["transactions"].reject! { |transaction| transaction["id"] == "relinked-coffee-1" } if only_second
        sync_again(@access, report: relinked)
        sync_it(@savings.reload.replacement, relinked) if sync_first
        carry_on(relinked)
        sync_again(@access, report: relinked)
      end
    end

    def relinked_and_synced(accounts, report)
      sync_again(@access, report:)
      accounts.map { |account| account.reload.replacement.tap { |replacement| sync_it(replacement, report) } }
    end

    def pair_by_hand(bank_transaction, partner)
      [ bank_transaction, partner ].each { |row| row.linked_transaction.update!(categorization: Transaction::Categorization.none) }
      bank_transaction.pair_with(partner)
    end

    def assert_transfers_point_at_each_other
      BankTransaction.find_each do |bank_transaction|
        assert_equal bank_transaction.paired?, bank_transaction.linked_transaction.transfer?, "#{bank_transaction.amount_in_cents} is a Transfer exactly when it has a partner"
        assert_equal bank_transaction, bank_transaction.transfer_partner.transfer_partner if bank_transaction.paired?
      end
    end

    def savings_rows
      @savings.reload.bank_transactions.map { |row| [ row.external_id, row.amount_in_cents, row.posted_at, row.linked_transaction.kept? ] }.sort_by(&:to_s)
    end

    def checking
      @checking ||= @access.bank_accounts.find_by!(external_id: "Demo Checking")
    end

    def synced_replacement
      sync_again(@access, report: relinked_report)
      @savings.reload.replacement.tap { |replacement| sync_it(replacement, relinked_report) }
    end

    def paired_copy
      copy = synced_replacement.bank_transactions.find_by!(amount_in_cents: -13550)
      partner = @access.bank_accounts.find_by!(external_id: "Demo Checking").bank_transactions.where(transfer_partner_id: nil).where.not(amount_in_cents: -17667).first
      copy.linked_transaction.update!(categorization: Transaction::Categorization.none)
      partner.linked_transaction.update!(categorization: Transaction::Categorization.none)
      copy.pair_with(partner)
      [ copy, partner ]
    end

    def missing_with_rows_before_posted_times(zone:)
      report = simplefin_report
      demo_account(report, "Demo Savings")["transactions"] << bought("late", "-12.00", Time.utc(2026, 10, 5, 6, 30))
      sync_again(@access, report:)
      travel 1.hour
      relinked_report(report).tap do |relinked|
        sync_again(@access, report: relinked)
        BankTransaction.update_all(posted_at: nil)
        users(:one).update!(time_zone: zone)
      end
    end

    def sync_it(bank_account, report)
      stub_simplefin_accounts(body: report.to_json)
      perform_enqueued_jobs { bank_account.sync_recent_history }
    end

    def relinked_ids
      demo_account(relinked_report, "Relinked Demo Savings")["transactions"].pluck("id").sort
    end

    def carry_on(report, account = @savings)
      stub_simplefin_accounts(body: report.to_json)
      perform_enqueued_jobs { BankAccount.find(account.id).carry_on_with_replacement }
    end

    def bought(id, amount, time, description: "Bike shop", posted: time)
      { "id" => id, "posted" => posted.to_i, "transacted_at" => time&.to_i, "amount" => amount, "description" => description }
    end

    def coffee(id, time, description: "Blue Bottle", posted: time)
      bought(id, "-4.00", time, description:, posted:)
    end

    def sent_later(report, external_id = "Demo Savings", by: 1.day)
      report.tap { demo_account(report, external_id)["balance-date"] += by.to_i }
    end
end
