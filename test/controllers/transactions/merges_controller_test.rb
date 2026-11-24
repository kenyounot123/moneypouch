require "test_helper"

class Transactions::MergesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
    activate(connect_simplefin)
    @typed = users(:one).transactions.create!(name: "Bait", amount_in_cents: -1_000, occurred_on: "2026-10-09")
    @bank_transaction = users(:one).bank_transactions.find_by!(amount_in_cents: -1_000)
  end

  test "removes the typed row and redirects back" do
    post transaction_merge_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }, headers: { "HTTP_REFERER" => simplefin_review_url(show: "duplicates") }

    assert_redirected_to simplefin_review_url(show: "duplicates")
    assert_equal 303, response.status
    assert_not users(:one).transactions.exists?(@typed.id)
    assert users(:one).transactions.exists?(@bank_transaction.transaction_id)
  end

  test "a second click changes nothing and redirects the same way" do
    post transaction_merge_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }

    assert_no_difference -> { users(:one).transactions.count } do
      post transaction_merge_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }
    end
    assert_redirected_to simplefin_review_url
  end

  test "a page that shows a bank row the user deleted since removes nothing" do
    Transaction.find(@bank_transaction.transaction_id).discard

    post transaction_merge_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }

    assert users(:one).transactions.exists?(@typed.id)
  end

  test "another user's rows stay as they are" do
    sign_in_as(users(:two))

    post transaction_merge_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }

    assert_response :see_other
    assert users(:one).transactions.exists?(@typed.id)
  end

  test "a request naming no bank row is refused" do
    post transaction_merge_url(@typed)

    assert_response :bad_request
    assert users(:one).transactions.exists?(@typed.id)
  end
end
