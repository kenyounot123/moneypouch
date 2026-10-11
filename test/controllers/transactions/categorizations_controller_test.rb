require "test_helper"

class Transactions::CategorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "picks an existing category and redirects back" do
    paycheck = transactions(:paycheck)

    assert_no_difference -> { Category.count } do
      patch transaction_categorization_url(paycheck), params: { categorization: { category: "food" } }, headers: { "HTTP_REFERER" => root_url }
    end

    assert_redirected_to root_url
    assert_equal 303, response.status
    assert_equal "Food", paycheck.reload.category.name
  end

  test "creates the category when the name is new" do
    assert_difference -> { users(:one).categories.count }, 1 do
      patch transaction_categorization_url(transactions(:paycheck)), params: { categorization: { category: "  Salary " } }
    end

    assert_equal "Salary", transactions(:paycheck).reload.category.name
  end

  test "a blank name clears the category" do
    patch transaction_categorization_url(transactions(:coffee)), params: { categorization: { category: "" } }

    assert_nil transactions(:coffee).reload.category
  end

  test "another user's transaction is not found" do
    sign_in_as(users(:two))

    patch transaction_categorization_url(transactions(:paycheck)), params: { categorization: { category: "Food" } }

    assert_response :not_found
    assert_nil transactions(:paycheck).reload.category
  end
end
