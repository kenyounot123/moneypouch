require "test_helper"

class RuleOfferTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    @access = activate(connect_simplefin)
  end

  test "a pick on a bank row asks under that row whether to make it a rule" do
    grocery = added_by_bank(-13_550)

    pick grocery, category: "Food"

    assert_nil Rule.first
    assert_select "li#transaction_#{grocery.id} p", text: "Always put transactions named “Grocery store” in the Food category?"
    assert_select "li#transaction_#{grocery.id} p", text: "3 more waiting now, plus future syncs."
    assert_select "li#transaction_#{grocery.id} button[data-action='dismiss#dismiss']", text: "Just this one"
    assert_select "li#transaction_#{grocery.id} form[action=?] button", transaction_rule_path(grocery), text: "Make a rule"
    assert_select "[data-controller=dismiss]", 1

    get simplefin_review_url
    assert_select "[data-controller=dismiss]", 0
  end

  test "a transfer pick asks to mark the name as a transfer" do
    shack = added_by_bank(-1_000)

    pick shack, transfer: "1"

    assert_select "li#transaction_#{shack.id} p", text: "Always mark transactions named “John's Fishin Shack” as Transfer?"
    assert_select "li#transaction_#{shack.id} p", text: "2 more waiting now, plus future syncs."
  end

  test "the picked row stays in its list so the question has a place" do
    grocery = added_by_bank(-13_550)

    pick grocery, category: "Food"

    assert_select "turbo-frame#needing_category_page_1 li#transaction_#{grocery.id}"
    assert_select "nav[aria-label=Lists] a", text: /Need a category\s+8/
  end

  test "no question when the account already has that rule, after a typed row, or after clearing" do
    grocery = added_by_bank(-13_550)
    grocery.categorize(Transaction::Categorization.new(category: categories(:food)))
    grocery.make_rule

    pick grocery, category: "Food"
    assert_select "[data-controller=dismiss]", 0

    pick transactions(:paycheck), category: "Food"
    assert_select "[data-controller=dismiss]", 0

    pick added_by_bank(-17_667), category: ""
    assert_select "[data-controller=dismiss]", 0
  end

  test "a pick on a later page asks when that page reloads" do
    report = simplefin_report
    rows = demo_account(report, "Demo Checking")["transactions"]
    55.times { |index| rows << rows[2].merge("id" => "more-#{index}", "amount" => "-#{index + 1}.00", "payee" => "Shop #{index}") }
    sync_again(@access, report:)
    grocery = added_by_bank(-13_550)

    pick grocery, category: "Food"
    assert_select "li#transaction_#{grocery.id}", 0

    get simplefin_review_url(show: "needing_category", page: 2), headers: { "Turbo-Frame" => "needing_category_page_2" }
    assert_select "li#transaction_#{grocery.id} [data-controller=dismiss]", 1

    get simplefin_review_url(show: "needing_category", page: 2), headers: { "Turbo-Frame" => "needing_category_page_2" }
    assert_select "[data-controller=dismiss]", 0
  end

  test "on the Overview the picked row stays in the bank block and asks once" do
    grocery = added_by_bank(-17_001)

    patch transaction_categorization_url(grocery), params: { categorization: { category: "Food" } }, headers: { "HTTP_REFERER" => root_url }
    follow_redirect!

    assert_select "#bank_review li#transaction_#{grocery.id} [data-controller=dismiss]", 1
    assert_select "li#transaction_#{grocery.id}", 2
    assert_select "[data-controller=dismiss]", 1
  end

  private
    def pick(transaction, category: "", transfer: "0")
      patch transaction_categorization_url(transaction), params: { categorization: { category:, transfer: } }, headers: { "HTTP_REFERER" => simplefin_review_url }
      follow_redirect!
    end

    def added_by_bank(cents)
      Transaction.find(BankTransaction.unmatched.find_by!(amount_in_cents: cents).transaction_id)
    end
end
