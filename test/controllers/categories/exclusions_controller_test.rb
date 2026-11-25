require "test_helper"

class Categories::ExclusionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
  end

  test "excluding a category takes its transactions out of the Overview, Trends, and Transactions totals" do
    today = Date.new(2026, 10, 20)
    overview = -> { Spending.new(users(:one).transactions, Period.new("month", today:)).total }
    trends = -> { Trends.new(users(:one).transactions, today:).months.sum(&:spent) }
    assert_equal [ 550, 550 ], [ overview.call, trends.call ]

    get transactions_url(month: "2026-10")
    assert_select "[data-field=spent]", text: "$5.50"

    post category_exclusion_url(categories(:food)), headers: { "HTTP_REFERER" => categories_url }

    assert_redirected_to categories_url
    assert_equal 303, response.status
    assert categories(:food).reload.excluded?
    assert_equal [ 0, 0 ], [ overview.call, trends.call ]

    get transactions_url(month: "2026-10")
    assert_select "[data-field=spent]", text: "$0.00"
    assert_select "[data-field=day-total]", text: "+$2,000.00"
    assert_select "li#transaction_#{transactions(:coffee).id} span", text: "Excluded"
    assert_select "li#transaction_#{transactions(:coffee).id} form[action=?]", transaction_exclusion_path(transactions(:coffee)), count: 0
  end

  test "the Manage menu offers Exclude, then Include once excluded" do
    get categories_url
    assert_select "li#category_#{categories(:food).id} form[action=?] button", category_exclusion_path(categories(:food)), text: "Exclude from totals"

    categories(:food).exclude
    get categories_url
    assert_select "li#category_#{categories(:food).id} form[action=?] button", category_exclusion_path(categories(:food)), text: "Include in totals"
  end

  test "an excluded category shows its real total, tagged and left out of the section total" do
    categories(:food).exclude

    get categories_url

    assert_select "section[aria-label=Spent] [data-field=section-total]", text: "—"
    assert_select "li#category_#{categories(:food).id}" do
      assert_select "span", text: "Excluded"
      assert_select "[data-field=total]", text: "$5.50"
      assert_select "[data-field=share]", text: ""
    end

    get category_url(categories(:food), months: 3)
    assert_select "h1 ~ span", text: "Excluded"
    assert_select "[data-field=total]", text: "$5.50"
  end

  test "a transaction added to an excluded category comes in excluded" do
    categories(:food).exclude

    added = users(:one).transactions.create!(name: "Tacos", amount_in_cents: -500, occurred_on: "2026-10-05", category: categories(:food))

    assert_not added.counted?
    assert_equal 0, users(:one).transactions.spent
  end

  test "including the category again keeps a hand-excluded transaction excluded" do
    transactions(:coffee).exclude
    users(:one).transactions.create!(name: "Tacos", amount_in_cents: -500, occurred_on: "2026-10-05", category: categories(:food))
    categories(:food).exclude

    delete category_exclusion_url(categories(:food))

    assert_not categories(:food).reload.excluded?
    assert_equal 500, users(:one).transactions.spent
    assert transactions(:coffee).reload.excluded?
  end

  test "uncategorized transactions still count while a category is excluded" do
    categories(:food).exclude
    users(:one).transactions.create!(name: "Cash", amount_in_cents: -700, occurred_on: "2026-10-05")

    assert_equal 700, users(:one).transactions.spent
    assert_equal 1, users(:one).transactions.counted.money_out.count
  end

  test "Income cannot be excluded" do
    post category_exclusion_url(categories(:income))

    assert_response :not_found
    assert_not categories(:income).reload.excluded?
  end

  test "another user's category is not found" do
    sign_in_as(users(:two))

    post category_exclusion_url(categories(:food))

    assert_response :not_found
    assert_not categories(:food).reload.excluded?
  end

  test "merging an excluded category into one that counts makes its transactions count" do
    categories(:food).exclude
    other = users(:one).categories.create!(name: "Meals")

    post category_merge_url(categories(:food)), params: { into: other.id }

    assert_equal 550, users(:one).transactions.spent
  end

  test "deleting an excluded category leaves its transactions uncategorized and counted" do
    categories(:food).exclude

    delete category_url(categories(:food))

    assert_nil transactions(:coffee).reload.category
    assert_equal 550, users(:one).transactions.spent
  end

  test "the merge and delete confirmations say the transactions count again" do
    categories(:food).exclude

    get categories_url

    assert_select "form[action=?][data-turbo-confirm*='count in your totals again']", category_merge_path(categories(:food))
    assert_select "button[aria-label='Delete Food']" do |button|
      assert_match "count in your totals again", button.first["data-turbo-confirm"]
    end
  end

  test "a row added through the composer into an excluded category is left out of totals" do
    categories(:food).exclude

    assert_difference("Transaction.count", 1) do
      post transactions_url, params: { shorthand: "tacos 5 #food", idempotency_key: "key-tacos" }
    end

    added = users(:one).transactions.find_by!(name: "tacos")
    assert_equal categories(:food), added.category
    assert_not added.counted?
    assert_equal 0, users(:one).transactions.spent

    get transactions_url(month: "2026-10")
    assert_select "[data-field=spent]", text: "$0.00"
    assert_select "li#transaction_#{added.id} span", text: "Excluded"
  end

  test "a row added by a bank sync into an excluded category is left out of totals" do
    users(:one).rules.create!(name: "Grocery store", name_key: "grocery store", category: categories(:food))
    categories(:food).exclude
    access = connect_simplefin
    activate(access, [ "Demo Savings" ])

    grocery = Transaction.find(BankTransaction.find_by!(external_id: "1790954910").transaction_id)
    assert_equal categories(:food), grocery.category
    assert_not grocery.counted?
    assert_not_includes users(:one).transactions.counted, grocery
    assert_equal users(:one).transactions.where(category: nil).money_out.sum("-amount_in_cents"), users(:one).transactions.spent
  end

  test "the merge menu marks an excluded target and the confirmation says the transactions leave your totals" do
    other = users(:one).categories.create!(name: "Meals")
    other.exclude

    get categories_url

    assert_select "select#into_category_#{categories(:food).id} option", text: "Meals (excluded)"
    assert_select "form[action=?][data-turbo-confirm*='leave your totals if that category is excluded']", category_merge_path(categories(:food))
  end

  test "merging a counted category into an excluded one takes its transactions out of totals" do
    other = users(:one).categories.create!(name: "Meals")
    other.exclude

    post category_merge_url(categories(:food)), params: { into: other.id }

    assert_equal 0, users(:one).transactions.spent
  end

  test "an excluded category is dimmed on the list and on its own page" do
    categories(:food).exclude

    get categories_url
    assert_select "li#category_#{categories(:food).id}" do
      assert_select "a.text-tertiary", text: "Food"
      assert_select "div.opacity-50[aria-hidden=true]"
      assert_select "[data-field=total].text-tertiary"
    end

    get category_url(categories(:food), months: 3)
    assert_select "nav.opacity-50[aria-label$='by month']"
    assert_select "[data-field=total].text-tertiary"

    categories(:food).include_in_totals
    get categories_url
    assert_select "li#category_#{categories(:food).id} a.text-tertiary", count: 0
    assert_select "li#category_#{categories(:food).id} div.opacity-50", count: 0
  end

  test "the CSV keeps Excluded as the transaction's own choice" do
    categories(:food).exclude

    get transactions_download_url(format: :csv)

    assert_equal [ nil ], CSV.parse(response.body, headers: true).select { |row| row["Name"] == "Blue Bottle" }.map { |row| row["Excluded"] }
  end
end
