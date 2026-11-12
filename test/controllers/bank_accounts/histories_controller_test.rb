require "test_helper"

class BankAccounts::HistoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 3, 18)
    sign_in_as(users(:one))
    @access = activate(connect_simplefin, history: "today")
    @savings = @access.bank_accounts.find_by!(external_id: "Demo Savings")
  end

  test "an account that started today brings in 90 days" do
    stub_simplefin_accounts

    perform_enqueued_jobs { post bank_account_history_url(@savings) }

    assert_redirected_to settings_url
    assert_equal Date.new(2026, 7, 6), @savings.reload.starts_on
    assert_operator @savings.bank_transactions.minimum(:occurred_on), :<, Date.new(2026, 10, 3)
  end

  test "bringing in 90 days again adds nothing new" do
    stub_simplefin_accounts
    perform_enqueued_jobs { post bank_account_history_url(@savings) }

    assert_no_difference -> { BankTransaction.count } do
      perform_enqueued_jobs { post bank_account_history_url(@savings) }
    end
  end

  test "settings offers 90 days only to an account that starts later" do
    get settings_url
    assert_select "##{dom_id(@savings)} button", text: "Bring in 90 days"

    stub_simplefin_accounts
    perform_enqueued_jobs { post bank_account_history_url(@savings) }

    get settings_url
    assert_select "##{dom_id(@savings)} button", text: "Bring in 90 days", count: 0
  end

  test "a revoked access offers nothing and cannot bring history in" do
    @access.revoke

    get settings_url
    assert_select "button", text: "Bring in 90 days", count: 0

    assert_no_enqueued_jobs only: Simplefin::SyncJob do
      post bank_account_history_url(@savings)
    end
    assert_response :not_found
  end

  test "an account not being synced is not found" do
    sync_again(@access, report: simplefin_report("errlist"))
    pending = @access.bank_accounts.find_by!(external_id: "Demo Card")

    post bank_account_history_url(pending)

    assert_response :not_found
    assert pending.reload.pending?
  end

  test "another user's account is not found" do
    sign_in_as(users(:two))

    post bank_account_history_url(@savings)

    assert_response :not_found
  end
end
