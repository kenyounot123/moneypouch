require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:two) }

  test "edit shows who is being reset" do
    get edit_password_path(@user.password_reset_token)

    assert_response :success
    assert_select "span", text: "two"
    assert_select "input[type=password][autocomplete=new-password][maxlength='72']", count: 2
  end

  test "a valid token changes the password and ends every session" do
    @user.sessions.create!

    patch password_path(@user.password_reset_token), params: { password: "new-secret", password_confirmation: "new-secret" }

    assert_redirected_to new_session_path
    assert_equal "Password changed. Sign in with your new password.", flash[:notice]
    assert @user.reload.authenticate("new-secret")
    assert_empty @user.sessions
  end

  test "a link works only once" do
    token = @user.password_reset_token
    patch password_path(token), params: { password: "new-secret", password_confirmation: "new-secret" }

    get edit_password_path(token)
    assert_redirected_to new_session_path
    assert_equal "That reset link has expired or was already used.", flash[:alert]

    patch password_path(token), params: { password: "another", password_confirmation: "another" }
    assert_redirected_to new_session_path
    assert @user.reload.authenticate("new-secret")
  end

  test "a link expires after a day" do
    token = @user.password_reset_token

    travel 25.hours
    get edit_password_path(token)

    assert_redirected_to new_session_path
    assert_equal "That reset link has expired or was already used.", flash[:alert]
  end

  test "a made-up token is refused" do
    get edit_password_path("nonsense")

    assert_redirected_to new_session_path
  end

  test "a mismatched confirmation shows the error and keeps the password" do
    patch password_path(@user.password_reset_token), params: { password: "new-secret", password_confirmation: "other" }

    assert_response :unprocessable_entity
    assert_select "p.text-danger", text: /Password confirmation doesn't match/
    assert @user.reload.authenticate("password")
  end

  test "a blank password shows the error" do
    patch password_path(@user.password_reset_token), params: { password: "", password_confirmation: "" }

    assert_response :unprocessable_entity
    assert_select "p.text-danger", text: /Password can't be blank/
  end
end
