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

  test "a new name on money in makes an income category, and on money out a spending one" do
    assert_difference -> { users(:one).categories.count }, 2 do
      patch transaction_categorization_url(transactions(:paycheck)), params: { categorization: { category: "  Salary " } }
      patch transaction_categorization_url(transactions(:coffee)), params: { categorization: { category: "Treats" } }
    end

    assert_equal [ "Salary", true ], [ transactions(:paycheck).reload.category.name, transactions(:paycheck).category.income? ]
    assert_equal [ "Treats", false ], [ transactions(:coffee).reload.category.name, transactions(:coffee).category.income? ]
  end

  test "a blank name clears the category" do
    patch transaction_categorization_url(transactions(:coffee)), params: { categorization: { category: "" } }

    assert_nil transactions(:coffee).reload.category
  end

  test "marks a transaction as a transfer and drops its category" do
    patch transaction_categorization_url(transactions(:coffee)), params: { categorization: { category: "", transfer: "1" } }

    coffee = transactions(:coffee).reload
    assert_equal [ true, nil ], [ coffee.transfer?, coffee.category ]
  end

  test "picking a category undoes a transfer" do
    transactions(:coffee).categorize(Transaction::Categorization.transfer)

    patch transaction_categorization_url(transactions(:coffee)), params: { categorization: { category: "Food" } }

    coffee = transactions(:coffee).reload
    assert_equal [ false, "Food" ], [ coffee.transfer?, coffee.category.name ]
  end

  test "another user's transaction is not found" do
    sign_in_as(users(:two))

    patch transaction_categorization_url(transactions(:paycheck)), params: { categorization: { category: "Food" } }

    assert_response :not_found
    assert_equal categories(:income), transactions(:paycheck).reload.category
  end
end
