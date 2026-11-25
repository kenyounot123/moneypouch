require "test_helper"

class GetStartedControllerTest < ActionDispatch::IntegrationTest
  test "hiding the list sends you back and keeps it hidden" do
    sign_in_as(users(:one))

    delete get_started_url, headers: { "HTTP_REFERER" => transactions_url }

    assert_redirected_to transactions_url
    assert_equal 303, response.status
    assert_predicate users(:one).reload, :get_started_hidden?
  end

  test "hiding the list lands on the Overview when there is nowhere to go back to" do
    sign_in_as(users(:one))

    delete get_started_url

    assert_redirected_to root_url
  end

  test "hiding the list is for someone who is signed in" do
    delete get_started_url

    assert_redirected_to new_session_url
    assert_not users(:one).reload.get_started_hidden?
  end

  test "hiding the list changes nobody else's" do
    sign_in_as(users(:one))

    delete get_started_url

    assert_not users(:two).reload.get_started_hidden?
  end
end
