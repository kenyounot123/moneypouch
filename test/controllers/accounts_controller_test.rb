require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  def empty_instance
    Transaction.delete_all
    User.destroy_all
  end

  test "a fresh instance shows the signup form" do
    empty_instance

    get new_account_path

    assert_response :success
    assert_select "h1", text: "Welcome to MoneyPouch"
  end

  test "the first signup signs in, then registration closes" do
    empty_instance

    assert_difference("User.count", 1) do
      post account_path, params: { user: { username: "newbie", password: "secret123" } }
    end

    assert_redirected_to first_transaction_path
    assert cookies[:session_id]
    assert User.find_by!(username: "newbie").owner?

    get new_account_path
    assert_redirected_to new_session_path
  end

  test "new is closed once an account exists" do
    get new_account_path

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "#alert", text: "Registration is closed."
  end

  test "create is closed once an account exists" do
    assert_no_difference("User.count") do
      post account_path, params: { user: { username: "newbie", password: "secret123" } }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "a signup form loaded while open fails once the owner closes registration" do
    users(:one).open_registration(true)
    get new_account_path
    assert_response :success

    users(:one).open_registration(false)

    assert_no_difference("User.count") do
      post account_path, params: { user: { username: "newbie", password: "secret123" } }
    end
    assert_redirected_to new_session_path
  end

  test "an open registration creates accounts" do
    users(:one).open_registration(true)

    assert_difference("User.count", 1) do
      post account_path, params: { user: { username: "newbie", password: "secret123" } }
    end

    assert_redirected_to first_transaction_path
    assert cookies[:session_id]
  end

  test "create with a taken username shows the error and keeps the username" do
    users(:one).open_registration(true)

    assert_no_difference("User.count") do
      post account_path, params: { user: { username: "one", password: "secret123" } }
    end

    assert_response :unprocessable_entity
    assert_select "#alert", text: "Username has already been taken"
    assert_select "input[name='user[username]'][value=one]"
    assert_nil cookies[:session_id]
  end
end
