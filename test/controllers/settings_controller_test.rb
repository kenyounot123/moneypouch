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
    assert_select "button[data-mode=dark]", text: "Dark"
  end

  test "offers every theme and marks the chosen one" do
    users(:one).choose_theme("moss")

    get settings_url

    assert_select "button[data-theme]", count: User::THEMES.size
    assert_select "button[data-theme=moss][aria-pressed=true]", text: "Moss"
    assert_select "button[aria-pressed=true]", count: 1
    assert_select "html[data-theme=moss][data-mode=light]"
  end

  test "shows the running version under About" do
    get settings_url

    assert_select "section h2", text: "About"
    assert_select "section:has(h2)", text: /About/ do
      assert_select "p", text: /\A\d+\.\d+\.\d+\z/
      assert_select "p", text: Release.current_version
    end
  end

  test "marks Settings as the current sidebar page" do
    get settings_url

    assert_select "aside a[aria-current=page]", text: "Settings", count: 1
    assert_select "aside a[aria-current=page]", count: 1
  end

  test "a mode change returns to settings" do
    patch mode_url, params: { mode: "dark" }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert_equal "dark", users(:one).reload.mode

    patch mode_url, params: { mode: "light" }, headers: { "HTTP_REFERER" => settings_url }
    assert_equal "light", users(:one).reload.mode
  end

  test "an unknown mode is refused" do
    patch mode_url, params: { mode: "neon" }

    assert_response :unprocessable_entity
    assert_equal "light", users(:one).reload.mode
  end

  test "a theme change returns to settings and keeps the mode" do
    users(:one).choose_mode("dark")

    patch theme_url, params: { theme: "ember" }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert_equal "ember", users(:one).reload.theme
    assert_equal "dark", users(:one).mode
  end

  test "an unknown theme is refused" do
    patch theme_url, params: { theme: "neon" }

    assert_response :unprocessable_entity
    assert_equal "pouch", users(:one).reload.theme
  end
end
