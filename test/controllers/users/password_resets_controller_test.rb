require "test_helper"

class Users::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  test "the owner gets a link for another account on Settings" do
    sign_in_as(users(:one))

    post user_password_reset_path(users(:two))

    assert_redirected_to settings_path
    follow_redirect!
    link = css_select("input#reset_link").first["value"]
    assert_equal users(:two), User.find_by_password_reset_token(link.split("/").second_to_last)
    assert_select "p", text: /Reset link for two\. It works once and expires in 24 hours\./
    assert_select "button", text: "Copy"
  end

  test "settings lists the other accounts and hides the list when there are none" do
    sign_in_as(users(:one))

    get settings_path
    assert_select "form[action=?] button", user_password_reset_path(users(:two)), text: "Reset link"
    assert_select "form[action=?]", user_password_reset_path(users(:one)), count: 0

    users(:two).destroy
    get settings_path
    assert_select "button", text: "Reset link", count: 0
  end

  test "a non-owner is refused" do
    sign_in_as(users(:two))

    post user_password_reset_path(users(:one))

    assert_response :forbidden
  end

  test "signed-out visitors are sent to sign in" do
    post user_password_reset_path(users(:two))

    assert_redirected_to new_session_path
  end

  test "the owner cannot make a link for themselves" do
    sign_in_as(users(:one))

    post user_password_reset_path(users(:one))

    assert_response :forbidden
  end
end
