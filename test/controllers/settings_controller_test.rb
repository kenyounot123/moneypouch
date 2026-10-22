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

  test "shows the running version under About" do
    get settings_url

    assert_select "section h2", text: "About"
    assert_select "section:has(h2)", text: /About/ do
      assert_select "p.text-secondary", text: /\A\d+\.\d+\.\d+\z/
      assert_select "p.text-secondary", text: Release.current_version
    end
  end

  test "marks Settings as the current sidebar page" do
    get settings_url

    assert_select "aside a[aria-current=page]", text: "Settings", count: 1
    assert_select "aside a[aria-current=page]", count: 1
  end

  test "a theme change returns to settings" do
    patch theme_url, params: { theme: "dark" }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert_equal "dark", users(:one).reload.theme

    patch theme_url, params: { theme: "light" }, headers: { "HTTP_REFERER" => settings_url }
    assert_equal "light", users(:one).reload.theme
  end

  test "an unknown theme is refused" do
    patch theme_url, params: { theme: "neon" }

    assert_response :unprocessable_entity
    assert_equal "light", users(:one).reload.theme
  end
end
