require "test_helper"

class SeenReleasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    users(:one).update!(seen_version: "0.5.0")
    sign_in_as(users(:one))
  end

  test "shows the release notes once to a user who hasn't seen the running version" do
    get root_url

    assert_select "dialog[aria-labelledby=release-notes-title]" do
      assert_select "h2", text: "You're now on version #{Release.current_version}"
      assert_select "h3", text: "0.6.0"
      assert_select "h4", text: "New"
      assert_select "li", text: "Download every transaction as a CSV file"
      assert_select "a[href='https://github.com/kenyounot123/moneypouch/releases'][target=_blank][rel=noopener]", text: "All releases"
      assert_select "button", text: "Got it"
    end
  end

  test "dismissing the notes marks them seen" do
    post seen_release_url, headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_response :see_other

    get root_url

    assert_select "dialog[aria-labelledby=release-notes-title]", count: 0
    assert_equal Release.current_version, users(:one).reload.seen_version
  end

  test "a user who has seen the running version gets no notes" do
    users(:one).see_releases

    get root_url

    assert_select "dialog[aria-labelledby=release-notes-title]", count: 0
  end

  test "the sign in page shows no notes" do
    delete session_url

    get new_session_url

    assert_select "dialog[aria-labelledby=release-notes-title]", count: 0
  end
end
