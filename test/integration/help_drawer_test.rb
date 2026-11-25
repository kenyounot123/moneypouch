require "test_helper"

class HelpDrawerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "the drawer explains the page you are on" do
    get transactions_url

    assert_select "aside#help-aside[aria-label=Help]" do
      assert_select "h3", text: "On this page"
      assert_select "dl dd", text: "Searches for food over $30."
      assert_select "details summary", text: "Record a refund"
      assert_select "details summary", text: "Why a transfer was marked for me"
      assert_select "details summary", text: "Why Trends is empty", count: 0
      assert_select "a[href=?]", help_path, text: "All topics"
      assert_select "button[data-action='shortcuts#showShortcuts']", text: "Keyboard shortcuts"
    end
  end

  test "each page opens with its own topics" do
    get root_url
    assert_select "aside#help-aside details summary", text: "Type a transaction"
    assert_select "aside#help-aside dl dd", text: "Income and spent, side by side, over six periods."

    get trends_url
    assert_select "aside#help-aside details summary", text: "Why Trends is empty"

    get settings_url
    assert_select "aside#help-aside details summary", text: "Connect a bank"
    assert_select "aside#help-aside dl dd", text: /A one-time code from SimpleFIN/

    get categories_url
    assert_select "aside#help-aside dl dd", text: "The last 12 months."

    get new_import_url
    assert_select "aside#help-aside details summary", text: "Import a file"
  end

  test "a phone gets the same help as a sheet" do
    get transactions_url

    assert_select "dialog[aria-label=Help][data-help-target=sheet]" do
      assert_select "details summary", text: "Record a refund"
      assert_select "button[data-action='help#close'][aria-label='Close help']"
    end
  end

  test "the Help page has no drawer and marks Help as the current page" do
    get help_url

    assert_select "aside#help-aside", count: 0
    assert_select "dialog[aria-label=Help]", count: 0
    assert_select "aside#sidebar a[href=?][aria-current=page]", help_path, text: /Help/
    assert_select "aside#sidebar a[data-help-target=opener]", count: 0
  end

  test "Help sits above Settings and opens the drawer from a link that works without scripts" do
    get root_url

    assert_select "aside#sidebar a[href=?][data-help-target=opener]", help_path, text: /Help/
    assert_select "aside#sidebar a[href=?]", settings_path, text: /Settings/
    assert_select "header a[href=?][aria-label=Help]", help_path
  end

  test "the sidebar offers the question mark key only while single-key shortcuts are on" do
    get root_url
    assert_select "aside#sidebar a[href=?][aria-keyshortcuts='?'] span", help_path, text: "?"

    users(:one).use_single_key_shortcuts(false)
    get root_url
    assert_select "aside#sidebar a[href=?][aria-keyshortcuts]", help_path, count: 0
    assert_select "aside#sidebar a[href=?] span", help_path, text: "?", count: 0
  end

  test "the drawer stays open from page to page through its cookie" do
    get root_url
    assert_select "html[data-help=closed]"

    cookies[:help] = "open"
    get transactions_url
    assert_select "html[data-help=open]"
  end
end
