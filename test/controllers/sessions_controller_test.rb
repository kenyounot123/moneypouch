require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "new sends a fresh server to create account" do
    Transaction.delete_all
    Category.delete_all
    Session.delete_all
    User.delete_all

    get new_session_path

    assert_redirected_to new_account_path
  end

  test "new tells a locked-out user where to get a reset" do
    get new_session_path

    assert_select "details summary", text: "Forgot your password?"
    assert_select "details p", text: /Ask the owner/
  end

  test "new hides the create account link while registration is closed" do
    get new_session_path
    assert_select "a[href=?]", new_account_path, count: 0

    users(:one).open_registration(true)
    get new_session_path
    assert_select "a[href=?]", new_account_path, text: "Create account"
  end

  test "create with valid credentials" do
    post session_path, params: { username: @user.username, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { username: @user.username, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
