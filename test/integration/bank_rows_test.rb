require "test_helper"

class BankRowsTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
  end

  test "rows from the bank carry the bank icon and typed rows keep an empty slot" do
    activate(connect_simplefin)

    get transactions_url

    assert_select "ul#transactions > li", 11
    assert_select "ul#transactions > li > div.w-4", 11
    assert_select "ul#transactions > li span.sr-only", text: "From your bank", count: 10
    assert_select "li#transaction_#{transactions(:coffee).id} span.sr-only", text: "From your bank"
    assert_select "li#transaction_#{transactions(:paycheck).id} span.sr-only", count: 0
  end

  test "imported rows with no category carry the marker and a matched row does not" do
    activate(connect_simplefin)
    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910", amount_in_cents: -13_550).transaction_id)

    get transactions_url

    assert_select "li#transaction_#{grocery.id} div.bg-highlight"
    assert_select "li#transaction_#{transactions(:coffee).id} div.bg-highlight", count: 0
    assert_select "ul#transactions div.bg-highlight", 9
  end

  test "the overview shows what the last sync brought in once" do
    activate(connect_simplefin)
    sync = Simplefin::Sync.sole

    get root_url

    assert_select "#toast_simplefin_sync_#{sync.id}[data-toast-seen-cookie-value=?]", "simplefin_sync_seen=#{sync.id}"
    assert_select "#toast_simplefin_sync_#{sync.id}", text: /9 new from your bank, 1 matched what you typed\s+Show new/
    assert_select "#toast_simplefin_sync_#{sync.id} a[href=?]", transactions_path(sync: sync.id)

    cookies[:simplefin_sync_seen] = sync.id.to_s
    get root_url
    assert_select "#toast_simplefin_sync_#{sync.id}", count: 0
  end

  test "the transactions page shows the toast too" do
    activate(connect_simplefin)

    get transactions_url

    assert_select "[data-controller=toast]", text: /9 new from your bank, 1 matched what you typed/
  end

  test "a sync that only matched says so without Show new" do
    report = simplefin_report
    savings = demo_account(report, "Demo Savings")
    savings["transactions"] = [ savings["transactions"][1] ]
    activate(connect_simplefin, [ "Demo Savings" ], report:)

    get root_url

    assert_select "[data-controller=toast]", text: "1 matched what you typed"
    assert_select "[data-controller=toast] a", count: 0
  end

  test "a sync that brought nothing shows no toast" do
    access = connect_simplefin
    activate(access)
    sync_again(access)
    cookies[:simplefin_sync_seen] = access.syncs.first.id.to_s

    get root_url

    assert_select "[data-controller=toast]", count: 0
  end

  test "Show new lists only the rows that sync added" do
    activate(connect_simplefin)

    get transactions_url(sync: Simplefin::Sync.sole.id)

    assert_select "ul#transactions > li", 9
    assert_select "li#transaction_#{transactions(:coffee).id}", count: 0
  end

  test "another user's sync is not found" do
    activate(connect_simplefin)
    sign_in_as(users(:two))

    get transactions_url(sync: Simplefin::Sync.sole.id)

    assert_response :not_found
  end
end
