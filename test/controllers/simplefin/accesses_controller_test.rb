require "test_helper"

class Simplefin::AccessesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
  end

  test "settings offers to connect a bank when none is connected" do
    get settings_url

    assert_select "turbo-frame#bank_sync h2", text: "Bank sync"
    assert_select "turbo-frame#bank_sync p", text: "Pull in transactions you didn't type."
    assert_select "turbo-frame#bank_sync a[href=?]", new_simplefin_access_path, text: "Connect a bank"
  end

  test "the connect step links to SimpleFIN and waits for a paste" do
    get new_simplefin_access_url

    assert_response :success
    assert_select "a[href='https://bridge.simplefin.org/simplefin/create'][target=_blank]", text: "Open SimpleFIN"
    assert_select "form[data-controller=paste-submit] input[name='simplefin_access[setup_token]'][data-action='input->paste-submit#submit']"
    assert_select "p#simplefin_access_setup_token_help", text: "Connects as soon as you paste."
    assert_select "a[href=?]", settings_path, text: "Cancel"
  end

  test "a good token connects and shows the accounts to pick" do
    stub_simplefin_claim
    stub_simplefin_accounts("balances")

    post simplefin_access_url, params: { simplefin_access: { setup_token: SETUP_TOKEN } }
    assert_redirected_to edit_simplefin_access_url
    follow_redirect!

    assert_select "p", text: "Connected. Pick the accounts you spend from."
    assert_select "label", text: /SimpleFIN Savings\s+SimpleFIN Bridge\s+\$114,685.51/
    assert_select "input[type=checkbox][checked]", count: 3
    assert_select "input[type=radio][name='simplefin_access[history]'][value=today][checked]"
    assert_select "button", text: "Start syncing ↵"
  end

  test "a used token keeps the paste and says how to recover" do
    stub_simplefin_claim(status: 403)

    post simplefin_access_url, params: { simplefin_access: { setup_token: SETUP_TOKEN } }

    assert_response :unprocessable_entity
    assert_select "input[name='simplefin_access[setup_token]'][value=?][aria-invalid=true]", SETUP_TOKEN
    assert_select "p#simplefin_access_setup_token_help.text-danger", text: "This token was already used. Get a new one from SimpleFIN."
    assert_nil users(:one).reload.simplefin_access
  end

  test "activating syncs the checked accounts from the chosen day" do
    access = connect_simplefin
    savings = access.bank_accounts.find_by!(external_id: "Demo Savings")

    patch simplefin_access_url, params: { simplefin_access: { account_ids: [ savings.id ], history: "90_days" } }

    assert_redirected_to settings_url
    assert_equal [ "synced", Date.new(2026, 10, 6) - 90 ], [ savings.reload.status, savings.starts_on ]
    assert_equal [ "skipped" ], access.bank_accounts.where.not(id: savings.id).distinct.pluck(:status)
    assert_enqueued_jobs 1, only: Simplefin::SyncJob
  end

  test "settings shows each synced account with its count after a sync" do
    activate(connect_simplefin)

    get settings_url

    assert_select "turbo-frame#bank_sync p", text: "Synced just now"
    assert_select "button", text: "Sync now"
    assert_select "li", text: /SimpleFIN Savings\s+SimpleFIN Bridge\s+5 transactions/
    assert_select "li", text: /SimpleFIN Checking\s+SimpleFIN Bridge\s+5 transactions/
    assert_select "li", text: /SimpleFIN Empty Account/, count: 0
    assert_select "p", text: "New banks you add on SimpleFIN show up here."
  end

  test "an account error shows SimpleFIN's message and offers the fix there" do
    access = connect_simplefin
    activate(access)
    sync_again(access, report: simplefin_report("errlist"))

    get settings_url

    assert_select "li", text: /SimpleFIN Savings.*Authentication with SimpleFIN Bridge is required.\s+Fix on SimpleFIN/m
    assert_select "li a[href='https://bridge.simplefin.org']", text: "Fix on SimpleFIN", count: 2
    assert_select "li", text: /SimpleFIN Credit Card\s+New\s+Added on SimpleFIN\s+Skip\s+Sync it/
  end

  test "a lapsed subscription offers renewal" do
    access = connect_simplefin
    activate(access)
    stub_simplefin_accounts(status: 402, body: "")
    perform_enqueued_jobs { access.sync_later }

    get settings_url

    assert_select "li", text: /Your SimpleFIN subscription ended\s+Renew it there and syncing picks up again.\s+Renew on SimpleFIN/
  end

  test "revoked access offers to reconnect and dims the accounts" do
    access = connect_simplefin
    activate(access)
    access.revoke

    get settings_url

    assert_select "turbo-frame#bank_sync p", text: "Last synced Oct 6"
    assert_select "li", text: /SimpleFIN stopped sharing your banks/
    assert_select "li a[href=?]", new_simplefin_access_path, text: "Reconnect"
    assert_select "li p.text-tertiary", text: "SimpleFIN Savings"
    assert_select "p", text: "Synced transactions stay if you disconnect."
    assert_select "button", text: "Sync now", count: 0
  end

  test "disconnecting returns to the empty state and keeps transactions" do
    activate(connect_simplefin)

    assert_no_difference -> { Transaction.count } do
      delete simplefin_access_url
    end

    assert_redirected_to settings_url
    follow_redirect!
    assert_select "a", text: "Connect a bank"
  end

  test "someone without a access cannot start, sync, or disconnect" do
    patch simplefin_access_url, params: { simplefin_access: { history: "today" } }
    assert_response :not_found

    post simplefin_sync_url
    assert_response :not_found

    delete simplefin_access_url
    assert_response :not_found
  end
end
