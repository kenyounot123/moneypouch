require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    sign_in_as(users(:one))
  end

  test "lists spending and income categories with this month's totals and a link to their transactions" do
    get categories_url

    assert_response :success
    assert_select "aside a[aria-current=page]", text: "Categories", count: 1
    assert_select "section[aria-labelledby=spending_heading] li#category_#{categories(:food).id}" do
      assert_select "input[name='category[name]'][value=Food]"
      assert_select "a[href='#{transactions_path(category: categories(:food).id)}']", text: "1 transaction"
      assert_select "p.font-mono", text: "$5.50"
      assert_select "button", text: "Count as income"
    end
    assert_select "section[aria-labelledby=income_heading] li#category_#{categories(:income).id}" do
      assert_select "p.font-mono", text: "$2,000.00"
      assert_select "button", text: "Count as spending"
    end
    assert_select "li#category_#{categories(:income_two).id}", count: 0
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

  test "moves a category between spending and income" do
    patch category_url(categories(:food)), params: { category: { income: "true" } }

    assert categories(:food).reload.income?
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

    assert_equal "Food", categories(:food).reload.name
  end
end
