require "test_helper"

class HelpControllerTest < ActionDispatch::IntegrationTest
  test "a signed-out visitor is sent to sign in" do
    get help_url

    assert_redirected_to new_session_url
  end

  test "explains every topic, grouped by section" do
    sign_in_as(users(:one))

    get help_url

    assert_response :success
    assert_select "h1", text: "Help"
    assert_select "input[aria-label='Search help']"
    Help::Topic.sections.each do |section, topics|
      assert_select "section##{section.parameterize} h2", text: section
      topics.each do |topic|
        assert_select "section##{section.parameterize} li##{topic.id} h3", text: topic.title
      end
    end
    assert_select "nav[aria-label=Sections] a", count: Help::Topic.sections.size
  end

  test "shows the parts of a transaction line and what happens when one is left out" do
    sign_in_as(users(:one))

    get help_url

    assert_select "li#help-type-a-transaction dt", text: "Amount"
    assert_select "li#help-type-a-transaction dd", text: /Required/, minimum: 2
    assert_select "li#help-type-a-transaction dd", text: /The last one used for that name/
  end
end
