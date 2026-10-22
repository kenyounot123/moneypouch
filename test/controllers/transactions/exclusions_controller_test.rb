require "test_helper"

class Transactions::ExclusionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "excludes a transaction and redirects back" do
    post transaction_exclusion_url(transactions(:coffee)), headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert transactions(:coffee).reload.excluded?
  end

  test "includes it again" do
    transactions(:coffee).update!(excluded: true)

    delete transaction_exclusion_url(transactions(:coffee))

    assert_not transactions(:coffee).reload.excluded?
  end

  test "another user's transaction is not found" do
    sign_in_as(users(:two))

    post transaction_exclusion_url(transactions(:coffee))

    assert_response :not_found
    assert_not transactions(:coffee).reload.excluded?
  end

  test "an excluded transaction stays listed, tagged, and out of the month totals" do
    transactions(:coffee).update!(excluded: true)

    get transactions_url(month: "2026-10")

    assert_select "li#transaction_#{transactions(:coffee).id} span", text: "Excluded"
    assert_select "li#transaction_#{transactions(:coffee).id} form[action=?] button[aria-label=Include][title=Include] .icon--include", transaction_exclusion_path(transactions(:coffee))
    assert_select "li#transaction_#{transactions(:paycheck).id} form[action=?] button[aria-label=Exclude][title=Exclude] .icon--exclude", transaction_exclusion_path(transactions(:paycheck))
    assert_select "p.text-display", text: "$0.00"
  end

  test "the sheet offers Exclude, then Include once excluded" do
    get edit_transaction_url(transactions(:coffee))

    assert_select "turbo-frame#sheet form[action=?] button", transaction_exclusion_path(transactions(:coffee)), text: "Exclude"

    transactions(:coffee).update!(excluded: true)
    get edit_transaction_url(transactions(:coffee))

    assert_select "turbo-frame#sheet form[action=?] button", transaction_exclusion_path(transactions(:coffee)), text: "Include"
  end
end
