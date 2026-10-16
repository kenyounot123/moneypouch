require "test_helper"

class Transactions::DownloadsControllerTest < ActionDispatch::IntegrationTest
  test "Download CSV sends only the signed-in user's transactions" do
    users(:two).transactions.create!(name: "Someone else's", amount_in_cents: -100, occurred_on: "2026-10-01")
    sign_in_as(users(:one))

    get transactions_download_url(format: :csv)

    assert_response :success
    assert_match "attachment; filename=\"moneypouch-", response.headers["Content-Disposition"]
    assert_equal users(:one).transactions.pluck(:name).sort, CSV.parse(response.body, headers: true).map { |row| row["Name"] }.sort
  end
end
