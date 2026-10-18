require "test_helper"

class Simplefin::SyncTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    @user = users(:one)
  end

  test "a first sync adds every transaction and matches the one the user typed" do
    access = connect_simplefin
    activate(access)

    sync = access.syncs.sole
    assert_nil sync.failure
    assert_equal [ 9, 1 ], [ sync.bank_transactions.count(&:unmatched?), sync.bank_transactions.count(&:matched?) ]
    assert_equal [ [ "You", 196_000, "2026-10-01" ], [ "You", 256_448, "2026-10-01" ],
                   [ "Grocery store", -13_550, "2026-10-02" ], [ "John's Fishin Shack", -665, "2026-10-02" ], [ "Grocery store", -17_667, "2026-10-02" ],
                   [ "John's Fishin Shack", -1000, "2026-10-03" ], [ "Grocery store", -13_000, "2026-10-03" ], [ "John's Fishin Shack", -1331, "2026-10-03" ], [ "Grocery store", -17_001, "2026-10-03" ] ],
      access.syncs.added_transactions.order(:occurred_on, :id).map { |transaction| [ transaction.name, transaction.amount_in_cents, transaction.occurred_on.iso8601 ] }
  end

  test "the typed match is linked, not duplicated, and keeps what the user typed" do
    access = connect_simplefin
    activate(access)

    coffee = transactions(:coffee).reload
    assert coffee.from_bank?
    assert coffee.bank_transaction.matched?
    assert_equal [ "Blue Bottle", "Food", "1790926110", "Demo Savings" ],
      [ coffee.name, coffee.category.name, coffee.bank_transaction.external_id, coffee.bank_transaction.bank_account.external_id ]
    assert_not coffee.added_by_bank?
    assert_not coffee.needs_category?
  end

  test "running the same sync again adds nothing" do
    access = connect_simplefin
    activate(access)

    assert_no_difference -> { Transaction.count } do
      assert_no_difference -> { BankTransaction.count } do
        sync_again(access)
      end
    end
    assert_empty access.syncs.last.bank_transactions
  end

  test "each bank transaction stores the key its cleaned name matches on" do
    access = connect_simplefin
    activate(access)

    assert_equal [ "grocery store", "johns fishin shack", "you" ], BankTransaction.distinct.pluck(:name_key).sort
  end

  test "the same bank id in two accounts adds both transactions" do
    access = connect_simplefin
    activate(access)

    assert_equal [ [ "Demo Checking", -665 ], [ "Demo Savings", -550 ] ],
      BankTransaction.where(external_id: "1790926110").map { |bank_transaction| [ bank_transaction.bank_account.external_id, bank_transaction.amount_in_cents ] }.sort
  end

  test "two equal bank transactions claim one typed match between them" do
    report = simplefin_report
    savings = demo_account(report, "Demo Savings")
    savings["transactions"] = [ savings["transactions"][1], savings["transactions"][1].merge("id" => "second-bait") ]
    access = connect_simplefin
    activate(access, [ "Demo Savings" ], report:)

    assert_equal [ [ "1790926110", true, transactions(:coffee).id ], [ "second-bait", false, Transaction.last.id ] ],
      BankTransaction.order(:external_id).map { |bank_transaction| [ bank_transaction.external_id, bank_transaction.matched, bank_transaction.transaction_id ] }
    assert_equal [ "John's Fishin Shack", -550 ], [ Transaction.last.name, Transaction.last.amount_in_cents ]
  end

  test "a bank row the user discarded stays discarded after the next sync" do
    access = connect_simplefin
    activate(access)
    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910", amount_in_cents: -13_550).transaction_id)
    grocery.discard

    assert_no_difference -> { Transaction.count } do
      sync_again(access)
    end
    assert grocery.reload.discarded_at.present?
  end

  test "a discarded typed row is not a match" do
    transactions(:coffee).discard
    access = connect_simplefin
    activate(access, [ "Demo Savings" ])

    assert_not transactions(:coffee).reload.from_bank?
    assert_equal 5, BankTransaction.unmatched.count
  end

  test "an account seen for the first time adds nothing until the user picks it" do
    report = simplefin_report
    report["accounts"] << demo_account(report, "Demo Checking").merge("id" => "Demo Brokerage", "name" => "SimpleFIN Brokerage")
    access = connect_simplefin
    activate(access, [ "Demo Savings" ], report:)

    brokerage = access.bank_accounts.find_by!(external_id: "Demo Brokerage")
    assert brokerage.pending?
    assert_equal({ "Demo Savings" => 5, "Demo Checking" => 0, "Demo Empty Account" => 0, "Demo Brokerage" => 0 },
      access.bank_accounts.to_h { |account| [ account.external_id, account.bank_transactions.count ] })
  end

  test "Sync it adds the account from today on the next sync" do
    report = simplefin_report
    access = connect_simplefin
    activate(access, [ "Demo Savings" ], report:)

    travel_to Time.utc(2026, 10, 3, 18)
    Time.use_zone("America/Los_Angeles") { access.bank_accounts.find_by!(external_id: "Demo Checking").start_syncing }
    sync_again(access, report:)

    assert_equal [ -1331, -17_001 ], access.bank_accounts.find_by!(external_id: "Demo Checking").bank_transactions.order(:id).pluck(:amount_in_cents)
  end

  test "bank transactions before the chosen start day are left as the user typed them" do
    travel_to Time.utc(2026, 10, 3, 18)
    access = connect_simplefin
    activate(access, history: "today")

    assert_equal [ "2026-10-03" ], BankTransaction.distinct.pluck(:occurred_on).map(&:iso8601)
    assert_equal 4, BankTransaction.count
  end

  test "a bank transaction falls on the user's day, not the server's" do
    report = simplefin_report
    savings = demo_account(report, "Demo Savings")
    savings["transactions"] = [ savings["transactions"].first, { "id" => "posted-only", "posted" => Time.utc(2026, 10, 2).to_i, "amount" => "-3.00", "description" => "Parking" } ]

    access = connect_simplefin(zone: "America/Los_Angeles")
    activate(access, [ "Demo Savings" ], report:)
    assert_equal({ "1790911710" => Date.new(2026, 10, 1), "posted-only" => Date.new(2026, 10, 2) },
      BankTransaction.pluck(:external_id, :occurred_on).to_h)

    elsewhere = connect_simplefin(users(:two), zone: "UTC")
    activate(elsewhere, [ "Demo Savings" ], report:)
    assert_equal Date.new(2026, 10, 2), elsewhere.bank_accounts.find_by!(external_id: "Demo Savings").bank_transactions.find_by!(external_id: "1790911710").occurred_on
  end

  test "a row added by the bank reuses the category the user gave that name before" do
    @user.transactions.create!(name: "Grocery store", amount_in_cents: -4000, occurred_on: Date.new(2026, 9, 1), category: categories(:food))
    access = connect_simplefin
    activate(access, [ "Demo Savings" ])

    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910").transaction_id)
    fishing = Transaction.find(BankTransaction.find_by!(external_id: "1791012510").transaction_id)
    assert_equal [ "Food", false ], [ grocery.category.name, grocery.needs_category? ]
    assert_equal [ nil, true ], [ fishing.category, fishing.needs_category? ]
    assert_equal [ true, true ], [ grocery.added_by_bank?, fishing.added_by_bank? ]

    fishing.categorize(Transaction::Categorization.transfer)
    assert_not fishing.needs_category?
  end

  test "a lapsed subscription is marked and recovers on the next good sync" do
    access = connect_simplefin
    activate(access)
    stub_simplefin_accounts(status: 402, body: "")
    perform_enqueued_jobs { access.sync_later }

    assert access.reload.lapsed?
    assert access.active?

    sync_again(access)
    assert_not access.reload.lapsed?
  end

  test "revoked access is marked and the dead URL is forgotten" do
    access = connect_simplefin
    activate(access)
    stub_simplefin_accounts(status: 403, body: "")
    perform_enqueued_jobs { access.sync_later }

    access.reload
    assert access.revoked?
    assert_nil access.access_url
    assert_equal "revoked", access.syncs.last.failure
  end

  test "a failed sync does not move the last synced time" do
    access = connect_simplefin
    activate(access)
    synced_at = access.last_synced_at

    travel 1.hour
    stub_simplefin_accounts(status: 500, body: "")
    perform_enqueued_jobs { access.sync_later }

    assert_equal "unavailable", access.syncs.last.failure
    assert_equal synced_at, access.last_synced_at
    assert_equal Time.utc(2026, 10, 6, 18), synced_at
  end

  test "SimpleFIN's error reaches each account it names and clears once fixed" do
    access = connect_simplefin
    activate(access)
    sync_again(access, report: simplefin_report("errlist"))

    assert_equal({ "Demo Savings" => "Authentication with SimpleFIN Bridge is required.",
                   "Demo Checking" => "Authentication with SimpleFIN Bridge is required.",
                   "Demo Empty Account" => nil,
                   "Demo Card" => "Could not get transactions for SimpleFIN Credit Card." },
      access.bank_accounts.to_h { |account| [ account.external_id, account.error_message ] })
    assert_nil access.syncs.last.failure

    sync_again(access)
    assert_equal [ nil ], access.bank_accounts.where(external_id: DEMO_ACCOUNTS).distinct.pluck(:error_message)
  end

  test "a sync that already finished does nothing" do
    access = connect_simplefin
    activate(access)
    stub_simplefin_accounts

    access.syncs.sole.run_now

    assert_requested :get, ACCOUNTS_URL, times: 2
  end

  test "a sync reads at most 89 days back" do
    access = connect_simplefin
    activate(access, history: "90_days")

    assert_requested :get, "https://beta-bridge.simplefin.org/simplefin/accounts?version=2&start-date=#{Time.new(2026, 7, 9, 0, 0, 0, "-07:00").to_i}"
  end

  test "a disconnect while the bank is answering keeps the sync abandoned and adds nothing" do
    access, sync = start_sync
    answer_after { access.reload.disconnect }

    assert_no_difference -> { Transaction.count } do
      sync.run_now
    end
    assert_equal [ "abandoned", "disconnected" ], [ sync.reload.failure, access.reload.status ]
  end

  test "a sync abandoned as stale while the bank is answering adds nothing" do
    _, sync = start_sync
    answer_after { travel(16.minutes) { Simplefin::Sync.abandon_stale } }

    assert_no_difference -> { Transaction.count } do
      sync.run_now
    end
    assert_equal "abandoned", sync.reload.failure
  end

  test "a revoked answer after a disconnect leaves the access disconnected" do
    access, sync = start_sync
    stub_request(:get, ACCOUNTS_URL).to_return { access.reload.disconnect; { status: 403 } }

    sync.run_now

    assert_equal [ "abandoned", "disconnected" ], [ sync.reload.failure, access.reload.status ]
  end

  test "the same sync run twice at once adds its transactions once" do
    access, sync = start_sync
    twin = Simplefin::Sync.find(sync.id)
    answer_after { answer_after { }; twin.run_now }

    sync.run_now

    assert_equal [ 9, nil ], [ access.syncs.added_transactions.count, sync.reload.failure ]
  end

  private
    def start_sync
      access = connect_simplefin
      access.activate(account_ids: access.bank_accounts.where(external_id: DEMO_ACCOUNTS).ids, history: "90_days")
      [ access, access.syncs.sole ]
    end

    def answer_after(&before_answering)
      body = simplefin_fixture("accounts")
      stub_request(:get, ACCOUNTS_URL).to_return { before_answering.call; { status: 200, body: } }
    end
end
