require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "the owner opens registration and signup works" do
    sign_in_as(users(:one))

    patch registration_url, params: { open: true }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert users(:one).reload.registration_open?
    assert_difference("User.count", 1) do
      post account_path, params: { user: { username: "newbie", password: "secret123" } }
    end
  end

  test "the owner closes registration again" do
    users(:one).open_registration(true)
    sign_in_as(users(:one))

    patch registration_url, params: { open: false }

    assert_not users(:one).reload.registration_open?
    get new_account_path
    assert_redirected_to new_session_path
  end

  test "a non-owner is refused and the flag stays" do
    sign_in_as(users(:two))

    patch registration_url, params: { open: true }

    assert_response :forbidden
    assert_not users(:two).reload.registration_open?
    assert_not users(:one).reload.registration_open?
    assert_not User.registration_open?
  end

  test "signed-out visitors cannot change it" do
    patch registration_url, params: { open: true }

    assert_redirected_to new_session_path
    assert_not users(:one).reload.registration_open?
  end
end
