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
    assert_select "section > ul button", text: "Sync it", count: 0
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

  test "settings says SimpleFIN stopped sending an account it sends only under a stale old id for a day" do
    sync_again(@access, report: relinked_report)
    perform_enqueued_jobs { post bank_account_replacement_url(@savings) }
    travel 1.hour
    sync_again(@access)

    get settings_url
    assert_select "##{dom_id(@savings)}", text: /stopped sending/, count: 0

    travel 1.day
    sync_again(@access)

    get settings_url
    assert_select "##{dom_id(@savings)}", text: /stopped sending this account/
  end

  test "a renamed account offers a choice among the new accounts from its bank" do
    report = simplefin_report
    demo_account(report, "Demo Savings").merge!("id" => "Renamed Savings", "name" => "Premier Savings")
    sync_again(@access, report:)
    renamed = @access.bank_accounts.find_by!(external_id: "Renamed Savings")

    get settings_url
    assert_select "##{dom_id(@savings)} select option", text: "Premier Savings · $114,685.51"
    assert_select "##{dom_id(@savings)} input[type=submit][value='Same account']"

    assert_no_difference -> { Transaction.count } do
      perform_enqueued_jobs { post bank_account_replacement_url(@savings), params: { replacement_id: renamed.id } }
    end

    assert_redirected_to settings_url
    assert_equal "Renamed Savings", @savings.reload.external_id
  end

  test "choices with one name show their balances" do
    report = simplefin_report
    demo_account(report, "Demo Savings").merge!("id" => "Renamed Savings", "name" => "Premier Savings", "balance" => "100.00")
    report["accounts"] << demo_account(report, "Renamed Savings").merge("id" => "Second Premier", "balance" => "250.00")
    sync_again(@access, report:)

    get settings_url

    assert_equal [ "Pick the same account", "Premier Savings · $100.00", "Premier Savings · $250.00" ], css_select("##{dom_id(@savings)} select option").map(&:text)
  end

  test "a skipped account never becomes the default pick for Same account" do
    report = simplefin_report
    savings = demo_account(report, "Demo Savings")
    report["accounts"].delete(savings)
    report["accounts"] << savings.merge("id" => "New Card", "name" => "Rewards Card", "transactions" => [])
    sync_again(@access, report:)
    card = @access.bank_accounts.find_by!(external_id: "New Card")
    patch bank_account_url(card), params: { bank_account: { status: "skipped" } }
    travel 1.hour
    report["accounts"] << savings.merge("id" => "Renamed Savings", "name" => "Premier Savings")
    sync_again(@access, report:)

    get settings_url

    select = css_select("##{dom_id(@savings)} select").first
    assert select.key?("required")
    options = css_select("##{dom_id(@savings)} select option")
    assert_equal "", options.first["value"]
    assert_equal "Pick the same account", options.first.text
    assert_equal [ "Premier Savings", "Rewards Card" ], options.drop(1).map { |option| option.text.split(" · ").first }
  end

  test "a single pending choice stays preselected without a prompt" do
    report = simplefin_report
    demo_account(report, "Demo Savings").merge!("id" => "Renamed Savings", "name" => "Premier Savings")
    sync_again(@access, report:)

    get settings_url

    assert_equal [ "Premier Savings · $114,685.51" ], css_select("##{dom_id(@savings)} select option").map(&:text)
    assert_not css_select("##{dom_id(@savings)} select").first.key?("required")
  end

  test "Same account without a pick changes nothing" do
    report = simplefin_report
    demo_account(report, "Demo Savings").merge!("id" => "Renamed Savings", "name" => "Premier Savings")
    report["accounts"] << demo_account(report, "Renamed Savings").merge("id" => "Second Premier")
    sync_again(@access, report:)

    assert_no_difference -> { BankAccount.count } do
      perform_enqueued_jobs { post bank_account_replacement_url(@savings), params: { replacement_id: "" } }
    end

    assert_redirected_to settings_url
    assert_equal "Demo Savings", @savings.reload.external_id
    assert @savings.missing?
    assert_enqueued_jobs 0
  end

  test "a choice from another bank is not found" do
    sync_again(@access, report: relinked_report)
    elsewhere = @access.bank_accounts.create!(external_id: "Elsewhere", name: "Elsewhere", institution: "Other Bank", currency: "USD")

    post bank_account_replacement_url(@savings), params: { replacement_id: elsewhere.id }

    assert_response :not_found
    assert @savings.reload.missing?
  end

  test "Stop syncing puts the missing account away and offers the other one as new" do
    sync_again(@access, report: relinked_report)

    assert_no_difference -> { Transaction.count } do
      patch bank_account_url(@savings), params: { bank_account: { status: "skipped" } }
    end

    assert @savings.reload.skipped?
    follow_redirect!
    assert_select "##{dom_id(@savings)}", count: 0
    assert_select "section > ul button", text: "Sync it", count: 1
    assert_select "details#not_syncing li", text: /SimpleFIN Savings/
  end

  test "a skipped account that replaces the missing one waits for Same account instead of Sync it" do
    report = simplefin_report
    report["accounts"] << demo_account(report, "Demo Savings").merge("id" => "Twin Savings", "transactions" => [])
    sync_again(@access, report:)
    twin = @access.bank_accounts.find_by!(external_id: "Twin Savings")
    twin.start_syncing(from: Date.current)
    sync_again(@access, report:)
    travel 1.hour
    sync_again(@access, report: relinked_report)
    replacement = @access.bank_accounts.find_by!(external_id: "Relinked Demo Savings")
    patch bank_account_url(replacement), params: { bank_account: { status: "skipped" } }
    patch bank_account_url(twin), params: { bank_account: { status: "skipped" } }

    get settings_url
    assert_select "##{dom_id(@savings)} button", text: "Same account"
    assert_select "##{dom_id(replacement, :stopped)}", count: 0

    assert_no_difference -> { @access.bank_accounts.synced.count } do
      perform_enqueued_jobs { patch bank_account_url(replacement), params: { bank_account: { status: "synced" } } }
    end
    assert replacement.reload.skipped?

    assert_no_difference -> { Transaction.count } do
      perform_enqueued_jobs { post bank_account_replacement_url(@savings) }
    end
    assert_equal "Relinked Demo Savings", @savings.reload.external_id
    assert_not BankAccount.exists?(replacement.id)
  end

  test "a skipped account from the missing one's bank is still offered as the same account" do
    report = simplefin_report
    demo_account(report, "Demo Savings").merge!("id" => "Renamed Savings", "name" => "Premier Savings")
    sync_again(@access, report:)
    renamed = @access.bank_accounts.find_by!(external_id: "Renamed Savings")
    patch bank_account_url(renamed), params: { bank_account: { status: "skipped" } }

    get settings_url
    assert_select "##{dom_id(@savings)} select option", text: "Premier Savings · $114,685.51"

    assert_no_difference -> { Transaction.count } do
      perform_enqueued_jobs { post bank_account_replacement_url(@savings), params: { replacement_id: renamed.id } }
    end
    assert_equal "Renamed Savings", @savings.reload.external_id
  end

  test "a stopped account that SimpleFIN sends again under its old id stays one account" do
    sync_again(@access, report: relinked_report)
    perform_enqueued_jobs { post bank_account_replacement_url(@savings) }
    travel 2.days
    without_savings = simplefin_report
    without_savings["accounts"].delete(demo_account(without_savings, "Demo Savings"))
    sync_again(@access, report: without_savings)
    assert @savings.reload.missing?
    patch bank_account_url(@savings), params: { bank_account: { status: "skipped" } }
    travel 1.hour

    assert_no_difference -> { @access.bank_accounts.count } do
      sync_again(@access, report: simplefin_report)
    end

    old_id_again = simplefin_report
    demo_account(old_id_again, "Demo Savings")["balance-date"] += 3.days.to_i
    stub_simplefin_accounts(body: old_id_again.to_json)
    assert_no_difference [ "@access.bank_accounts.count", "Transaction.count", "BankTransaction.count" ] do
      perform_enqueued_jobs { patch bank_account_url(@savings), params: { bank_account: { status: "synced" } } }
    end
    assert_equal [ "synced", "Demo Savings" ], [ @savings.reload.status, @savings.external_id ]
    assert_equal demo_account(simplefin_report, "Demo Savings")["transactions"].pluck("id").sort, @savings.bank_transactions.pluck(:external_id).sort
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
