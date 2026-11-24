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

    assert_equal [ "Possible duplicates 0", "Need a category 4", "Categorized for you 4", "Transfers 1" ], css_select("nav[aria-label=Lists] a").map { _1.text.squish }
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
    assert_select "li[data-just-made]", 1
  end

  test "with no rules yet the panel says where they come from" do
    get simplefin_review_url

    assert_select "section ul li", text: "Rules you make show up here."
  end

  test "Done marks every sync reviewed and goes to the Overview" do
    sync_again(@access)
    Simplefin::Sync.added_transactions.update_all(category_id: categories(:food).id)

    post simplefin_review_completion_url

    assert_redirected_to root_url
    assert_equal [ 2, 0 ], [ @access.syncs.count, @access.syncs.where(reviewed_at: nil).count ]

    get simplefin_review_url
    assert_select "main", text: /Nothing new from your bank/
  end

  test "Done keeps the rows that still need a category" do
    added_by_bank(-13_550).categorize(Transaction::Categorization.new(category: categories(:food)))
    added_by_bank(-1_000).categorize(Transaction::Categorization.transfer)

    post simplefin_review_completion_url
    get simplefin_review_url

    assert_equal [ "Possible duplicates 0", "Need a category 7", "Categorized for you 0", "Transfers 0" ], css_select("nav[aria-label=Lists] a").map { _1.text.squish }
    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Need a category/
    assert_select "turbo-frame#needing_category_page_1 li", 7
    assert_select "main", text: /Nothing new from your bank/, count: 0
    assert_select "form[action=?]", simplefin_review_completion_path, count: 0
  end

  test "possible duplicates open first, with where each row came from and buttons that name the row" do
    typed_bait

    get simplefin_review_url

    assert_select "nav[aria-label=Lists] a[aria-current=true][href=?]", simplefin_review_path(show: "duplicates"), text: /Possible duplicates\s+1/
    assert_select "main p", text: "Same transaction keeps the bank's rows and removes the one you added."
    assert_select "main", text: /Bait\s+Oct 5 · Typed in\s+\$10\.00\s+John's Fishin Shack\s+Oct 3 · SimpleFIN Savings\s+\$10\.00/
    assert_select "button[aria-label='Same transaction, Bait, Oct 5, $10.00']", text: "Same transaction"
    assert_select "button[aria-label='Keep both, Bait, Oct 5, $10.00']", text: "Keep both"
    assert_select "main", text: /Adds up to/, count: 0
  end

  test "the other lists stay a click away from the duplicates" do
    typed_bait

    get simplefin_review_url(show: "needing_category")

    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Need a category/
    assert_select "turbo-frame#needing_category_page_1 li", 9
    assert_select "button", text: "Same transaction", count: 0
  end

  test "with no duplicates the list says so" do
    get simplefin_review_url(show: "duplicates")

    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Possible duplicates\s+0/
    assert_select "main li", text: "No possible duplicates."
    assert_select "main p", text: /Same transaction keeps/, count: 0
  end

  test "duplicates keep the page reachable after Done with nothing left to categorize" do
    typed_bait
    Simplefin::Sync.added_transactions.update_all(category_id: categories(:food).id)
    post simplefin_review_completion_url

    get simplefin_review_url

    assert_equal [ "Possible duplicates 1", "Need a category 0", "Categorized for you 0", "Transfers 0" ], css_select("nav[aria-label=Lists] a").map { _1.text.squish }
    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Possible duplicates/
    assert_select "button", text: "Same transaction", count: 1
    assert_select "form[action=?]", simplefin_review_completion_path, count: 0
  end

  test "shows fifty duplicates and counts them all" do
    add_possible_duplicates(52)

    get simplefin_review_url

    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Possible duplicates\s+52/
    assert_select "button", text: "Same transaction", count: 50
  end

  test "more duplicates take no more queries" do
    add_possible_duplicates(1)
    get simplefin_review_url
    few = count_queries { get simplefin_review_url }
    add_possible_duplicates(20)

    assert_equal few, count_queries { get simplefin_review_url }
    assert_select "button", text: "Same transaction", count: 21
  end

  test "a user with no bank connection gets not found" do
    sign_in_as(users(:two))

    get simplefin_review_url

    assert_response :not_found
  end

  private
    def typed_bait
      users(:one).transactions.create!(name: "Bait", amount_in_cents: -1_000, occurred_on: "2026-10-05")
    end

    def add_possible_duplicates(count)
      report = simplefin_report
      rows = demo_account(report, "Demo Checking")["transactions"]
      amounts = (1..count).map { |number| 2_000_000 + count * 1_000 + number }
      amounts.each { |cents| rows << rows[2].merge("id" => "dear-#{cents}", "amount" => format("-%.2f", cents / 100.0)) }
      sync_again(@access, report:)
      import = users(:one).start_import(upload("dear-#{count}.csv", [ "Date,Name,Amount", *amounts.map { |cents| "2026-10-04,Dear #{cents},#{format("%.2f", cents / 100.0)}" } ].join("\n")))
      import.complete
    end

    def count_queries(&)
      count = 0
      ActiveSupport::Notifications.subscribed(->(*) { count += 1 }, "sql.active_record", &)
      count
    end

    def added_by_bank(cents)
      Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: cents).transaction_id)
    end
end
