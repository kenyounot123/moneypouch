require "test_helper"

class Transactions::NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "saves a note and redirects back" do
    patch transaction_note_url(transactions(:coffee)), params: { transaction: { note: "  Paid Wendy back  " } }, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert_equal "Paid Wendy back", transactions(:coffee).reload.note
  end

  test "a blank note clears it" do
    transactions(:coffee).update!(note: "Paid Wendy back")

    patch transaction_note_url(transactions(:coffee)), params: { transaction: { note: " " } }

    assert_nil transactions(:coffee).reload.note
  end

  test "another user's transaction is not found" do
    sign_in_as(users(:two))

    patch transaction_note_url(transactions(:coffee)), params: { transaction: { note: "Mine" } }

    assert_response :not_found
    assert_nil transactions(:coffee).reload.note
  end

  test "a row shows its note on its own line and offers Add a note when it has none" do
    transactions(:coffee).update!(note: "Paid Wendy back")

    get transactions_url

    assert_select "li#transaction_#{transactions(:coffee).id} button[data-action='note#open']", text: "Paid Wendy back"
    assert_select "li#transaction_#{transactions(:coffee).id} button[data-action='note#open'][aria-label='Add a note']", count: 0
    assert_select "li#transaction_#{transactions(:paycheck).id} [role=group][aria-label=Actions] > button[data-action='note#open'][aria-label='Add a note'][title='Add a note'] .icon--note"
    assert_select "li#transaction_#{transactions(:paycheck).id} [role=group][aria-label=Actions] > button[aria-label='Add a note'] + form[action$='/exclusion']"
  end
end
