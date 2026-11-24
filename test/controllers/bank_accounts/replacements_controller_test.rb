require "test_helper"

class BankAccounts::ReplacementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    @access = activate(connect_simplefin)
    @savings = @access.bank_accounts.find_by!(external_id: "Demo Savings")
    travel 1.hour
  end

  test "settings asks about a relinked account in place of offering it as new" do
    sync_again(@access, report: relinked_report)

    get settings_url

    assert_select "##{dom_id(@savings)}", text: /stopped sending this account/
    assert_select "##{dom_id(@savings)} button", text: "Same account"
    assert_select "##{dom_id(@savings)} button", text: "Stop syncing"
    assert_select "button", text: "Sync it", count: 0
  end

  test "Same account carries the old account on" do
    sync_again(@access, report: relinked_report)

    assert_no_difference -> { Transaction.count } do
      perform_enqueued_jobs { post bank_account_replacement_url(@savings) }
    end

    assert_redirected_to settings_url
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
    follow_redirect!
    assert_select "##{dom_id(@savings)}", text: /stopped sending/, count: 0
    assert_select "##{dom_id(@savings)}", text: /5 transactions/
  end

  test "Stop syncing puts the missing account away and offers the other one as new" do
    sync_again(@access, report: relinked_report)

    assert_no_difference -> { Transaction.count } do
      patch bank_account_url(@savings), params: { bank_account: { status: "skipped" } }
    end

    assert @savings.reload.skipped?
    follow_redirect!
    assert_select "##{dom_id(@savings)}", count: 0
    assert_select "button", text: "Sync it", count: 1
  end

  test "a missing account with no replacement offers SimpleFIN and Stop syncing" do
    report = simplefin_report
    report["accounts"].delete(demo_account(report, "Demo Savings"))
    sync_again(@access, report:)

    get settings_url

    assert_select "##{dom_id(@savings)} a", text: "Fix on SimpleFIN"
    assert_select "##{dom_id(@savings)} button", text: "Stop syncing"
    assert_select "##{dom_id(@savings)} button", text: "Same account", count: 0

    post bank_account_replacement_url(@savings)
    assert_response :not_found
  end

  test "a synced replacement does not offer 90 days while the missing account waits" do
    sync_again(@access, report: relinked_report)
    replacement = @savings.reload.replacement
    replacement.start_syncing(from: Date.current)

    get settings_url

    assert_select "##{dom_id(replacement)}"
    assert_select "##{dom_id(replacement)} button", text: "Bring in 90 days", count: 0
  end

  test "a missing account cannot be synced again from its row" do
    sync_again(@access, report: relinked_report)

    patch bank_account_url(@savings), params: { bank_account: { status: "synced" } }

    assert_response :not_found
  end

  test "an account SimpleFIN still sends is not found" do
    post bank_account_replacement_url(@savings)

    assert_response :not_found
  end

  test "another user's account is not found" do
    sync_again(@access, report: relinked_report)
    sign_in_as(users(:two))

    post bank_account_replacement_url(@savings)

    assert_response :not_found
    assert @savings.reload.missing?
  end
end
