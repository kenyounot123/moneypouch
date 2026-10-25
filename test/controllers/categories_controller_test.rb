require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
  end

  test "lists spending and income categories with their totals over the last 3 months" do
    users(:one).transactions.create!(name: "Tacos", amount_in_cents: -900, occurred_on: "2026-08-12", category: categories(:food))

    get categories_url

    assert_response :success
    assert_select "aside a[aria-current=page]", text: "Categories", count: 1
    assert_select "nav[aria-label=Period] a[aria-current=true]", text: "Last 3 months"
    assert_select "section[aria-label=Spent] [data-field=section-total]", text: "$14.50"
    assert_select "section[aria-label=Income] [data-field=section-total]", text: "$2,000.00"
    assert_select "li#category_#{categories(:food).id}" do
      assert_select "a[href='#{category_path(categories(:food), months: 3)}']", text: "Food"
      assert_select "[data-field=total]", text: "$14.50"
      assert_select "button[aria-label='Manage Food']"
      assert_select "input[name='category[name]'][value=Food]"
      assert_select "select[name=into]"
      assert_select "button[aria-label='Delete Food']"
    end
    assert_select "li#category_#{categories(:income).id}" do
      assert_select "[data-field=total]", text: "$2,000.00"
      assert_select "button[aria-label='Manage Income']", count: 0
    end
    assert_select "li#category_#{categories(:income_two).id}", count: 0
    assert_select "li", text: /transaction/, count: 0
  end

  test "every total follows the period picked, and a category's last transaction shows only on its own page" do
    trip = users(:one).categories.create!(name: "Trip")
    users(:one).transactions.create!(name: "Flight", amount_in_cents: -40_000, occurred_on: "2026-07-07", category: trip)

    users(:one).transactions.where(category: categories(:income)).delete_all

    get categories_url(months: 1)

    assert_select "nav[aria-label=Period] a[aria-current=true]", text: "October"
    assert_select "section[aria-label=Income] [data-field=section-total]", text: "—"
    assert_select "li#category_#{trip.id}" do
      assert_select "[data-field=total]", text: "—"
      assert_select "[data-field=share]", text: ""
      assert_select "[data-field=last-transaction]", count: 0
    end
    assert_select "li#category_#{trip.id} ~ li#category_#{categories(:food).id}", count: 0

    get categories_url(months: 12)

    assert_select "li#category_#{trip.id} [data-field=total]", text: "$400.00"
    assert_select "li#category_#{trip.id} [data-field=share]", text: /\A(<1|\d+)%\z/

    get category_url(trip, months: 1)

    assert_select "[data-field=last-transaction]", text: "Jul 7"
  end

  test "a category's page totals the same span as the list and lists its transactions" do
    users(:one).transactions.create!(name: "Tacos", amount_in_cents: -900, occurred_on: "2026-08-12", category: categories(:food))
    users(:one).transactions.create!(name: "Refund", amount_in_cents: 200, occurred_on: "2026-10-03", category: categories(:food))

    get category_url(categories(:food))

    assert_response :success
    assert_select "aside a[aria-current=page]", text: "Categories", count: 1
    assert_select "h1", text: "Food"
    assert_select "p", text: "Spent in the last 3 months"
    assert_select "[data-field=total]", text: "$12.50"
    assert_select "[data-field=refunded]", text: "After $2.00 in refunds"
    assert_select "[data-field=name]", text: "Tacos"
    assert_select "nav[aria-label='Spent by month'] a", count: 12
    assert_select "nav[aria-label='Spent by month'] a[aria-label='August 2026: $9.00']"

    get category_url(categories(:food), month: "2026-08")

    assert_select "p", text: "Spent in August"
    assert_select "[data-field=total]", text: "$9.00"
    assert_select "[data-field=name]", text: transactions(:coffee).name, count: 0
    assert_select "nav[aria-label=Period] a[aria-current=true]", count: 0
  end

  test "an empty span says when the category was last used and offers that month" do
    trip = users(:one).categories.create!(name: "Trip")
    users(:one).transactions.create!(name: "Flight", amount_in_cents: -40_000, occurred_on: "2026-07-07", category: trip)

    get category_url(trip)

    assert_select "[data-field=total]", text: "—"
    assert_select "[data-field=empty]", text: /No transactions in the last 3 months. The last one was on Jul 7./
    assert_select "[data-field=empty] a[href='#{category_path(trip, month: "2026-07")}']", text: "Show July 2026"
  end

  test "an income category shows its income" do
    get category_url(categories(:income), months: 1)

    assert_select "p", text: "Income in October"
    assert_select "[data-field=total]", text: "$2,000.00"
    assert_select "button[aria-label='Manage Income']", count: 0
  end

  test "renames a category and goes back to the page it was renamed on" do
    patch category_url(categories(:food)), params: { category: { name: "Eating out" } }

    assert_redirected_to categories_url
    assert_equal "Eating out", categories(:food).reload.name

    patch category_url(categories(:food)), params: { category: { name: "Food" } }, headers: { "Referer" => category_url(categories(:food), months: 12) }

    assert_redirected_to category_url(categories(:food), months: 12)
  end

  test "a name another category has shows why it was refused" do
    patch category_url(categories(:food)), params: { category: { name: "Income" } }
    follow_redirect!

    assert_select "#alert", text: "Income is already a category. Merge into it instead."
    assert_equal "Food", categories(:food).reload.name
  end

  test "a blank name is refused" do
    patch category_url(categories(:food)), params: { category: { name: " " } }
    follow_redirect!

    assert_select "#alert", text: "Name can't be blank"
    assert_equal "Food", categories(:food).reload.name
  end

  test "a category's income setting does not change from this page" do
    patch category_url(categories(:food)), params: { category: { name: "Food", income: "true" } }

    assert_not categories(:food).reload.income?
  end

  test "Income cannot be renamed, merged away, or deleted" do
    patch category_url(categories(:income)), params: { category: { name: "Salary" } }
    assert_response :not_found

    post category_merge_url(categories(:income)), params: { into: categories(:food).id }
    assert_response :not_found

    delete category_url(categories(:income))
    assert_response :not_found

    assert_equal "Income", categories(:income).reload.name
  end

  test "another category merges into Income" do
    salary = users(:one).categories.create!(name: "Salary", income: true)

    post category_merge_url(salary), params: { into: categories(:income).id }

    assert_not Category.exists?(salary.id)
  end

  test "deletes a category and leaves its transactions uncategorized" do
    delete category_url(categories(:food))

    assert_redirected_to categories_url
    assert_not Category.exists?(categories(:food).id)
    assert_nil transactions(:coffee).reload.category
  end

  test "merges a category into another" do
    foods = users(:one).categories.create!(name: "Foods")
    tacos = users(:one).transactions.create!(name: "Tacos", amount_in_cents: -900, occurred_on: "2026-10-02", category: foods)

    post category_merge_url(foods), params: { into: categories(:food).id }

    assert_redirected_to categories_url
    assert_not Category.exists?(foods.id)
    assert_equal categories(:food), tacos.reload.category
  end

  test "will not merge a category into itself or into another user's category" do
    post category_merge_url(categories(:food)), params: { into: categories(:food).id }
    assert_response :not_found

    post category_merge_url(categories(:food)), params: { into: categories(:income_two).id }
    assert_response :not_found

    assert Category.exists?(categories(:food).id)
  end

  test "another user's category is not found" do
    sign_in_as(users(:two))

    patch category_url(categories(:food)), params: { category: { name: "Mine" } }
    assert_response :not_found

    delete category_url(categories(:food))
    assert_response :not_found

    get category_url(categories(:food))
    assert_response :not_found

    assert_equal "Food", categories(:food).reload.name
  end
end
