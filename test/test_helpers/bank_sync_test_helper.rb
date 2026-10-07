module BankSyncTestHelper
  DEMO_ACCOUNTS = [ "Demo Savings", "Demo Checking" ].freeze

  def connect_simplefin(user = users(:one), zone: "America/Los_Angeles")
    stub_simplefin_claim
    stub_simplefin_accounts("balances")
    user.update!(time_zone: zone)
    Time.use_zone(zone) { user.connect_simplefin(SimplefinTestHelper::SETUP_TOKEN) }
  end

  def activate(access, external_ids = DEMO_ACCOUNTS, history: "90_days", report: simplefin_report)
    stub_simplefin_accounts(body: report.to_json)
    account_ids = access.bank_accounts.where(external_id: external_ids).ids

    perform_enqueued_jobs do
      Time.use_zone(access.time_zone) { access.activate(account_ids:, history:) }
    end
    access.reload
  end

  def sync_again(access, report: simplefin_report)
    stub_simplefin_accounts(body: report.to_json)
    perform_enqueued_jobs { access.sync_later }
    access.reload
  end

  def simplefin_report(fixture = "accounts")
    JSON.parse(simplefin_fixture(fixture))
  end

  def demo_account(report, external_id)
    report["accounts"].find { |account| account["id"] == external_id }
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include ActiveJob::TestHelper
  include BankSyncTestHelper
end
