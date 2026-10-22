require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages run only this origin's scripts and the importmap's nonced one" do
    sign_in_as(users(:one))

    get root_url

    policy = response.headers["Content-Security-Policy"]
    nonce = policy[/'nonce-([^']+)'/, 1]
    assert_match "script-src 'self' 'nonce-", policy
    assert_select "script[type=importmap][nonce=?]", nonce
    assert_select "[onclick], [onchange], [onsubmit], [oninput]", count: 0
  end
end
