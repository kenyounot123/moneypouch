require "test_helper"

class Simplefin::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    @access = activate(connect_simplefin)
  end

  test "lists what the sync brought in by what it still needs" do
    grocery = imported(-13_550)
    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
    imported(-1_000).categorize(Transaction::Categorization.transfer)

    get simplefin_review_url

    assert_select "main section", 3
    assert_select "main section:nth-of-type(1) h2", "Need a category"
    assert_select "main section:nth-of-type(1) li", 6
    assert_select "main section:nth-of-type(1) li span", text: "Oct 3 · SimpleFIN Checking"
    assert_select "main section:nth-of-type(2) h2", "Categorized for you"
    assert_select "main section:nth-of-type(2) li", 2
    assert_select "main section:nth-of-type(3) h2", "Transfers"
    assert_select "main section:nth-of-type(3) li", 1
    assert_select "li#transaction_#{transactions(:coffee).id}", count: 0
  end

  test "Done marks every sync reviewed and goes to the Overview" do
    sync_again(@access)

    patch simplefin_review_url

    assert_redirected_to root_url
    assert_equal [ 2, 0 ], [ @access.syncs.count, @access.syncs.where(reviewed_at: nil).count ]

    get simplefin_review_url
    assert_select "main", text: /Nothing new from your bank/
  end

  test "a user with no bank connection gets not found" do
    sign_in_as(users(:two))

    get simplefin_review_url

    assert_response :not_found
  end

  private
    def imported(cents)
      Transaction.find(BankTransaction.imported.find_by!(amount_in_cents: cents).transaction_id)
    end
end
