require "test_helper"

class Simplefin::AccessTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
  end

  test "connecting lists the accounts to pick from" do
    access = connect_simplefin

    assert access.pending?
    assert_equal "America/Los_Angeles", access.time_zone
    assert_equal [ [ "Demo Savings", "SimpleFIN Savings", "SimpleFIN Bridge", 11_468_551, "pending" ],
                   [ "Demo Checking", "SimpleFIN Checking", "SimpleFIN Bridge", 2_503_551, "pending" ],
                   [ "Demo Empty Account", "SimpleFIN Empty Account", "SimpleFIN Bridge", 0, "pending" ] ],
      access.bank_accounts.order(:id).pluck(:external_id, :name, :institution, :balance_in_cents, :status)
  end

  test "the access URL is stored encrypted" do
    access = connect_simplefin

    raw = Simplefin::Access.connection.select_value("SELECT access_url FROM simplefin_accesses WHERE id = #{access.id}")
    assert_not_includes raw, "simplefin"
    assert_equal ACCESS_URL, access.reload.access_url
  end

  test "a rejected token creates no access" do
    stub_simplefin_claim(status: 403)

    assert_raises(Simplefin::TokenRejected) { users(:one).connect_simplefin(SETUP_TOKEN) }
    assert_nil users(:one).reload.simplefin_access
  end

  test "activating syncs the chosen accounts from the chosen day and skips the rest" do
    access = connect_simplefin

    assert_enqueued_jobs 1, only: Simplefin::SyncJob do
      Time.use_zone("America/Los_Angeles") do
        access.activate(account_ids: access.bank_accounts.where(external_id: "Demo Savings").ids, history: "90_days")
      end
    end

    assert access.reload.active?
    assert_equal({ "Demo Savings" => [ "synced", Date.new(2026, 7, 8) ], "Demo Checking" => [ "skipped", nil ], "Demo Empty Account" => [ "skipped", nil ] },
      access.bank_accounts.to_h { |account| [ account.external_id, [ account.status, account.starts_on ] ] })
  end

  test "asking to sync while a sync runs returns the running sync" do
    access = connect_simplefin
    access.update!(status: :active)

    first = access.sync_later
    second = access.sync_later

    assert_equal first, second
    assert_equal 1, access.syncs.count
    assert_enqueued_jobs 1, only: Simplefin::SyncJob
  end

  test "a sync stuck for more than 15 minutes is abandoned by the next request" do
    access = connect_simplefin
    stuck = access.sync_later

    travel 16.minutes
    fresh = access.sync_later

    assert_not_equal stuck, fresh
    assert_equal "abandoned", stuck.reload.failure
  end

  test "the hourly sweep syncs only accesss with no sync in the last 23 hours" do
    access = connect_simplefin
    activate(access)
    stub_simplefin_accounts(status: 503, body: "")
    perform_enqueued_jobs { access.sync_later }
    assert_equal 2, access.syncs.count

    travel 22.hours
    assert_no_enqueued_jobs(only: Simplefin::SyncJob) { Simplefin::Access.sync_due }

    travel 2.hours
    assert_enqueued_jobs(1, only: Simplefin::SyncJob) { Simplefin::Access.sync_due }
  end

  test "the hourly sweep probes a lapsed subscription and leaves a revoked one alone" do
    lapsed = connect_simplefin(users(:one))
    lapsed.update!(status: :active)
    lapsed.syncs.create!(finished_at: 1.day.ago, failure: "lapsed", created_at: 1.day.ago)
    revoked = connect_simplefin(users(:two))
    revoked.update!(status: :revoked)

    assert_enqueued_jobs(1, only: Simplefin::SyncJob) { Simplefin::Access.sync_due }
    assert lapsed.lapsed?
    assert_equal [ 2, 0 ], [ lapsed.syncs.count, revoked.syncs.count ]
  end

  test "Sync now is held back after 20 syncs in a day" do
    access = connect_simplefin
    20.times { access.syncs.create!(finished_at: Time.current) }

    assert_not access.syncable?
    travel 25.hours
    assert access.syncable?
  end

  test "disconnecting forgets the access URL and keeps every imported row" do
    access = connect_simplefin
    activate(access)

    assert_no_difference -> { Transaction.count } do
      assert_no_difference -> { BankTransaction.count } do
        access.disconnect
      end
    end

    assert access.reload.disconnected?
    assert_nil access.access_url
    assert_equal [ 11, 10 ], [ users(:one).transactions.count, access.bank_accounts.sum { |account| account.bank_transactions.count } ]
  end

  test "reconnecting reuses the access and keeps the accounts picked before" do
    access = connect_simplefin
    activate(access, [ "Demo Savings" ])
    access.disconnect

    again = connect_simplefin

    assert_equal access.id, again.id
    assert again.pending?
    assert_equal ACCESS_URL, again.access_url
    assert_equal({ "Demo Savings" => "synced", "Demo Checking" => "skipped", "Demo Empty Account" => "skipped" },
      again.bank_accounts.to_h { |account| [ account.external_id, account.status ] })
  end

  test "a lapsed subscription stays lapsed through an unavailable sync and clears on a good one" do
    access = connect_simplefin
    access.syncs.create!(finished_at: 3.hours.ago, failure: "lapsed", created_at: 3.hours.ago)
    access.syncs.create!(finished_at: 2.hours.ago, failure: "unavailable", created_at: 2.hours.ago)
    access.syncs.create!(finished_at: 1.hour.ago, failure: "abandoned", created_at: 1.hour.ago)

    assert access.lapsed?

    access.syncs.create!(finished_at: 1.minute.ago, created_at: 1.minute.ago)

    assert_not access.lapsed?
  end
end
