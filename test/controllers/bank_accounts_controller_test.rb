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

  test "Sync it starts the new account 90 days back" do
    patch bank_account_url(@card), params: { bank_account: { status: "synced" } }

    assert_redirected_to settings_url
    assert_equal [ "synced", Date.new(2026, 7, 9) ], [ @card.reload.status, @card.starts_on ]
  end

  test "Sync it brings in the new account's recent history right away" do
    report = simplefin_report("errlist")
    demo_account(report, "Demo Card")["transactions"] = [
      { "id" => "card-1", "posted" => 30.days.ago.to_i, "amount" => "-25.00", "description" => "Bike shop" }
    ]
    stub_simplefin_accounts(body: report.to_json)

    perform_enqueued_jobs { patch bank_account_url(@card), params: { bank_account: { status: "synced" } } }

    assert_equal [ -2500 ], @card.bank_transactions.pluck(:amount_in_cents)
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
