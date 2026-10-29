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

  test "the owner sees the registration toggle" do
    get settings_url

    assert_select "form[action=?] button", registration_path, text: "Open registration"

    users(:one).open_registration(true)
    get settings_url

    assert_select "form[action=?] button", registration_path, text: "Close registration"
  end

  test "a non-owner sees no registration toggle" do
    sign_in_as(users(:two))

    get settings_url

    assert_select "form[action=?]", registration_path, count: 0
  end

  test "the sidebar opens the add palette here too" do
    get settings_url

    assert_select "aside button[aria-haspopup=dialog][data-action='dialog-opener#open'][data-dialog-opener-id-param=palette]", text: /Add/
    assert_select "header button[data-dialog-opener-id-param=palette]", text: /Add/
    assert_select "dialog#palette form[action=?] input[name=shorthand]", transactions_path
  end

  test "an add from here returns here with its undo" do
    post transactions_url, params: { shorthand: "tea 3", idempotency_key: "key-1" }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    follow_redirect!
    assert_select "#toast_transaction_#{Transaction.order(:id).last.id}", text: /Added\s+tea\s+\$3.00\s+Undo/
    assert_select "dialog#palette input[name=shorthand][value='']"
  end

  test "offers every theme and marks the chosen one" do
    users(:one).choose_theme("moss")

    get settings_url

    assert_select "button[data-theme]", count: User::THEMES.size
    assert_select "button[data-theme=moss][aria-pressed=true]", text: "Moss"
    assert_select "button[data-theme][aria-pressed=true]", count: 1
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

  test "single-key shortcuts show as on until turned off" do
    get settings_url

    assert_select "section:has(h2)", text: /Keyboard/ do
      assert_select "p", text: "Single-key shortcuts"
      assert_select "form[action=?] button[aria-pressed=true]", shortcuts_path, text: "On"
      assert_select "form[action=?] button[aria-pressed=false]", shortcuts_path, text: "Off"
    end
    assert_select "body[data-shortcuts-single-key-value=true]"

    users(:one).use_single_key_shortcuts(false)
    get settings_url

    assert_select "form[action=?] button[aria-pressed=true]", shortcuts_path, text: "Off"
    assert_select "form[action=?] button[aria-pressed=false]", shortcuts_path, text: "On"
    assert_select "body[data-shortcuts-single-key-value=false]"
  end

  test "turning single-key shortcuts off and on returns to settings" do
    patch shortcuts_url, params: { on: false }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert_not users(:one).reload.single_key_shortcuts?

    patch shortcuts_url, params: { on: true }, headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert users(:one).reload.single_key_shortcuts?
  end

  test "the page body listens for shortcuts and knows where transactions are" do
    get settings_url

    assert_select "body[data-controller=shortcuts][data-action='keydown@window->shortcuts#press'][data-shortcuts-transactions-url-value=?]", transactions_path
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
