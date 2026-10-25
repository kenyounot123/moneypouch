require "test_helper"

class Transactions::SuggestionsControllerTest < ActionDispatch::IntegrationTest
  test "lists the signed-in user's merchants, most frequent first, with how often each appears" do
    users(:one).transactions.create!(name: "Blue Bottle", amount_in_cents: -450, occurred_on: "2026-10-02")
    users(:one).transactions.create!(name: "Blue Bottle", amount_in_cents: -475, occurred_on: "2026-10-03")
    users(:one).transactions.create!(name: "Gone", amount_in_cents: -100, occurred_on: "2026-10-03", discarded_at: Time.current)
    users(:two).transactions.create!(name: "Someone else's", amount_in_cents: -100, occurred_on: "2026-10-01")
    sign_in_as(users(:one))

    get transactions_suggestions_url

    assert_response :success
    assert_equal [ { "name" => "Blue Bottle", "count" => 3 }, { "name" => "Paycheck", "count" => 1 } ], response.parsed_body
  end

  test "requires signing in" do
    get transactions_suggestions_url

    assert_redirected_to new_session_url
  end
end
