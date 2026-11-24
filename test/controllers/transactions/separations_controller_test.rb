require "test_helper"

class Transactions::SeparationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
    activate(connect_simplefin)
    @typed = users(:one).transactions.create!(name: "Bait", amount_in_cents: -1_000, occurred_on: "2026-10-09")
    @bank_transaction = users(:one).bank_transactions.find_by!(amount_in_cents: -1_000)
  end

  test "keeps both rows, stops offering them, and redirects back" do
    assert_no_difference -> { users(:one).transactions.count } do
      post transaction_separation_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }, headers: { "HTTP_REFERER" => simplefin_review_url(show: "duplicates") }
    end

    assert_redirected_to simplefin_review_url(show: "duplicates")
    assert_equal 303, response.status
    assert_empty users(:one).possible_duplicates.to_a
  end

  test "a second click, and Same transaction after it, change nothing" do
    post transaction_separation_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }

    assert_no_difference -> { users(:one).transactions.count } do
      post transaction_separation_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }
      post transaction_merge_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }
    end
    assert_redirected_to simplefin_review_url
  end

  test "another user's rows are still offered" do
    sign_in_as(users(:two))

    post transaction_separation_url(@typed), params: { bank_transaction_ids: [ @bank_transaction.id ] }

    assert_response :see_other
    assert_equal 1, users(:one).possible_duplicates.size
  end
end
