require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_account_path

    assert_response :success
    assert_select "h1", text: "Welcome to MoneyPouch"
  end

  test "create signs the new user in and sends them to the first transaction" do
    assert_difference("User.count", 1) do
      post account_path, params: { user: { username: "newbie", password: "secret123" } }
    end

    assert_redirected_to first_transaction_path
    assert cookies[:session_id]
    assert_equal "newbie", User.order(:id).last.username
  end

  test "create with a taken username shows the error and keeps the username" do
    assert_no_difference("User.count") do
      post account_path, params: { user: { username: "one", password: "secret123" } }
    end

    assert_response :unprocessable_entity
    assert_select "#alert", text: "Username has already been taken"
    assert_select "input[name='user[username]'][value=one]"
    assert_nil cookies[:session_id]
  end
end
