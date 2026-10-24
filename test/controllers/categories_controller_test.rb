require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
  end

  test "lists every category in one list with this month's totals and a link to each one's page" do
    get categories_url

    assert_response :success
    assert_select "aside a[aria-current=page]", text: "Categories", count: 1
    assert_select "section", count: 1
    assert_select "li#category_#{categories(:food).id}" do
      assert_select "input[name='category[name]'][value=Food]"
      assert_select "a[href='#{category_path(categories(:food))}']", text: "1 transaction"
      assert_select "p.font-amount", text: "$5.50"
      assert_select "select[name=into]"
      assert_select "button[aria-label='Delete Food']"
    end
    assert_select "li#category_#{categories(:income).id}" do
      assert_select "p.font-amount", text: "$2,000.00"
      assert_select "input[name='category[name]']", count: 0
      assert_select "select[name=into]", count: 0
      assert_select "button[aria-label='Delete Income']", count: 0
    end
    assert_select "button", text: /Count as/, count: 0
    assert_select "li#category_#{categories(:income_two).id}", count: 0
  end

  test "shows one month of a category's transactions and what they add up to" do
    users(:one).transactions.create!(name: "Tacos", amount_in_cents: -900, occurred_on: "2026-09-12", category: categories(:food))

    get category_url(categories(:food))

    assert_response :success
    assert_select "aside a[aria-current=page]", text: "Categories", count: 1
    assert_select "h1", text: "Food"
    assert_select "[data-field=total]", text: "$5.50"
    assert_select "[data-field=name]", text: transactions(:coffee).name
    assert_select "[data-field=name]", text: "Tacos", count: 0

    get category_url(categories(:food), month: "2026-09")

    assert_select "[data-field=total]", text: "$9.00"
    assert_select "[data-field=name]", text: "Tacos"
  end

  test "an income category shows what came in" do
    get category_url(categories(:income))

    assert_select "p", text: "Received in October"
    assert_select "[data-field=total]", text: "$2,000.00"
  end

  test "renames a category" do
    patch category_url(categories(:food)), params: { category: { name: "Eating out" } }

    assert_redirected_to categories_url
    assert_equal "Eating out", categories(:food).reload.name
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
