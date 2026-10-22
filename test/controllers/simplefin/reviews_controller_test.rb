require "test_helper"

class Simplefin::ReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    @access = activate(connect_simplefin)
  end

  test "opens on the rows that need a category, with each list's count in its tab" do
    added_by_bank(-13_550).categorize(Transaction::Categorization.new(category: categories(:food)))
    added_by_bank(-13_550).make_rule
    added_by_bank(-1_000).categorize(Transaction::Categorization.transfer)

    get simplefin_review_url

    assert_equal [ "Need a category 4", "Categorized for you 4", "Transfers 1" ], css_select("nav[aria-label=Lists] a").map { _1.text.squish }
    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Need a category/
    assert_select "turbo-frame#needing_category_page_1 li", 4
    assert_select "turbo-frame#needing_category_page_1 li:first-child", text: /Category\s+· Oct 3\s+· SimpleFIN Checking/
    assert_select "li#transaction_#{transactions(:coffee).id}", count: 0
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", root_path, text: "Overview"
    assert_select "nav[aria-label=Breadcrumb] [aria-current=page]", text: "From your bank"
    assert_select "h1", text: "From your bank"
  end

  test "show picks a list" do
    added_by_bank(-1_000).categorize(Transaction::Categorization.transfer)

    get simplefin_review_url(show: "transfers")

    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Transfers/
    assert_select "turbo-frame#transfers_page_1 li", 1
    assert_select "turbo-frame#transfers_page_1 li", text: /Fishin Shack/
  end

  test "a list with no rows says so" do
    get simplefin_review_url(show: "transfers")

    assert_select "turbo-frame#transfers_page_1 li", "No transfers."
  end

  test "with nothing left to categorize it opens on the next list with rows" do
    Simplefin::Sync.added_transactions.update_all(category_id: categories(:food).id)

    get simplefin_review_url(show: "anything")

    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Categorized for you/
    assert_select "turbo-frame#categorized_page_1 li", 9
  end

  test "shows fifty rows and loads the next fifty when the list end scrolls into view" do
    report = simplefin_report
    rows = demo_account(report, "Demo Checking")["transactions"]
    55.times { |index| rows << rows[2].merge("id" => "more-#{index}", "amount" => "-#{index + 1}.00", "payee" => "Shop #{index}") }
    sync_again(@access, report:)

    get simplefin_review_url

    assert_select "turbo-frame#needing_category_page_1 > li", 50
    assert_select "turbo-frame#needing_category_page_2[loading=lazy][src=?]", simplefin_review_path(show: "needing_category", page: 2)

    get simplefin_review_url(show: "needing_category", page: 2)

    assert_select "turbo-frame#needing_category_page_2 > li", 14
    assert_select "turbo-frame#needing_category_page_3", count: 0
  end

  test "lists rules newest first and the rows they cover" do
    added_by_bank(-13_550).categorize(Transaction::Categorization.new(category: categories(:food)))
    added_by_bank(-13_550).make_rule
    travel 2.minutes
    added_by_bank(-1_000).categorize(Transaction::Categorization.transfer)
    added_by_bank(-1_000).make_rule

    get simplefin_review_url

    assert_select "section h2", "Rules"
    assert_equal [ "“John's Fishin Shack” Transfer 3 rows · just now Forget", "“Grocery store” Food 4 rows Forget" ],
      css_select("section:has(h2) ul li").map { _1.text.squish }
    assert_select "li.bg-highlight\\/14", 1
  end

  test "with no rules yet the panel says where they come from" do
    get simplefin_review_url

    assert_select "section ul li", text: "Rules you make show up here."
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
    def added_by_bank(cents)
      Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: cents).transaction_id)
    end
end
