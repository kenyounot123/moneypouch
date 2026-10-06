require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "shows who is signed in and the account controls" do
    get settings_url

    assert_response :success
    assert_select "p", text: "Signed in as one"
    assert_select "button", text: "Sign out"
    assert_select "button[data-theme=dark]", text: "Dark"
  end

  test "marks Settings as the current sidebar page" do
    get settings_url

    assert_select "aside a[aria-current=page]", text: "Settings", count: 1
    assert_select "aside a[aria-current=page]", count: 1
  end

  test "a theme change returns to settings" do
    patch dark_theme_url, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert_equal "dark", users(:one).reload.background
  end

  test "light theme change returns to settings" do
    patch light_theme_url, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
  end
end
