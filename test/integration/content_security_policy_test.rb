require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages run only this origin's scripts and the importmap's nonced one" do
    sign_in_as(users(:one))

    get root_url

    policy = response.headers["Content-Security-Policy"]
    nonce = policy[/'nonce-([^']+)'/, 1]
    assert_match "script-src 'self' 'nonce-", policy
    assert_select "script[type=importmap][nonce=?]", nonce
    assert_match "style-src 'self' 'nonce-#{nonce}'", policy
    assert_select "meta[name=csp-nonce][content=?]", nonce
    assert_select "[style]", count: 0
    assert_select "[onclick], [onchange], [onsubmit], [oninput]", count: 0
  end

  test "the unsupported browser page is styled by a stylesheet this origin serves" do
    sign_in_as(users(:one))

    get root_url, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/80.0.0.0 Safari/537.36" }

    assert_response :not_acceptable
    assert_match "style-src 'self' 'nonce-", response.headers["Content-Security-Policy"]
    assert_select "style, [style]", count: 0
    stylesheet = css_select("link[rel=stylesheet]").sole["href"]
    assert Rails.public_path.join(stylesheet.delete_prefix("/")).file?
  end
end
