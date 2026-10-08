require "test_helper"

class BankAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    access = connect_simplefin
    activate(access)
    sync_again(access, report: simplefin_report("errlist"))
    @card = access.bank_accounts.find_by!(external_id: "Demo Card")
  end

  test "Sync it starts the new account from today" do
    patch bank_account_url(@card), params: { bank_account: { status: "synced" } }

    assert_redirected_to settings_url
    assert_equal [ "synced", Date.new(2026, 10, 6) ], [ @card.reload.status, @card.starts_on ]
  end

  test "Skip hides the new account" do
    patch bank_account_url(@card), params: { bank_account: { status: "skipped" } }

    assert @card.reload.skipped?
    follow_redirect!
    assert_select "li", text: /SimpleFIN Credit Card/, count: 0
  end

  test "an account already decided cannot be flipped from here" do
    savings = users(:one).bank_accounts.find_by!(external_id: "Demo Savings")

    patch bank_account_url(savings), params: { bank_account: { status: "skipped" } }

    assert_response :not_found
    assert savings.reload.synced?
  end

  test "an unknown status is a bad request" do
    patch bank_account_url(@card), params: { bank_account: { status: "pending" } }

    assert_response :bad_request
  end

  test "another user's account is not found" do
    sign_in_as(users(:two))

    patch bank_account_url(@card), params: { bank_account: { status: "skipped" } }

    assert_response :not_found
  end
end
