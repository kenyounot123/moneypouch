require "test_helper"

class Transactions::ExclusionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "excludes a transaction and redirects back" do
    patch transaction_exclusion_url(transactions(:coffee)), params: { transaction: { excluded: true } }, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert transactions(:coffee).reload.excluded?
  end

  test "includes it again" do
    transactions(:coffee).update!(excluded: true)

    patch transaction_exclusion_url(transactions(:coffee)), params: { transaction: { excluded: false } }

    assert_not transactions(:coffee).reload.excluded?
  end

  test "another user's transaction is not found" do
    sign_in_as(users(:two))

    patch transaction_exclusion_url(transactions(:coffee)), params: { transaction: { excluded: true } }

    assert_response :not_found
    assert_not transactions(:coffee).reload.excluded?
  end

  test "an excluded transaction stays listed, tagged, and out of the month totals" do
    transactions(:coffee).update!(excluded: true)

    get transactions_url(month: "2026-10")

    assert_select "li#transaction_#{transactions(:coffee).id} span", text: "Excluded"
    assert_select "li#transaction_#{transactions(:coffee).id} form[action=?] button", transaction_exclusion_path(transactions(:coffee)), text: "Include in totals"
    assert_select "li#transaction_#{transactions(:coffee).id} form[action=?] button[aria-label='Include in totals'] .icon--include", transaction_exclusion_path(transactions(:coffee))
    assert_select "li#transaction_#{transactions(:paycheck).id} form[action=?] button", transaction_exclusion_path(transactions(:paycheck)), text: "Exclude from totals"
    assert_select "li#transaction_#{transactions(:paycheck).id} form[action=?] button[aria-label='Exclude from totals'] .icon--exclude", transaction_exclusion_path(transactions(:paycheck))
    assert_select "p.text-display", text: "$0.00"
  end

  test "the sheet offers Exclude from totals, then Include in totals once excluded" do
    get edit_transaction_url(transactions(:coffee))

    assert_select "turbo-frame#sheet form[action=?] button", transaction_exclusion_path(transactions(:coffee)), text: "Exclude from totals"

    transactions(:coffee).update!(excluded: true)
    get edit_transaction_url(transactions(:coffee))

    assert_select "turbo-frame#sheet form[action=?] button", transaction_exclusion_path(transactions(:coffee)), text: "Include in totals"
  end
end
