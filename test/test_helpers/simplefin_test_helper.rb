require "webmock/minitest"

module SimplefinTestHelper
  ACCESS_URL = "https://demo:secret@beta-bridge.simplefin.org/simplefin"
  CLAIM_URL = "https://beta-bridge.simplefin.org/simplefin/claim/DEMO-v2-TEST"
  SETUP_TOKEN = Base64.strict_encode64(CLAIM_URL)
  ACCOUNTS_URL = %r{\Ahttps://beta-bridge\.simplefin\.org/simplefin/accounts\?}

  def stub_simplefin_claim(status: 200)
    stub_request(:post, CLAIM_URL).to_return(status:, body: status == 200 ? "#{ACCESS_URL}\n" : "Forbidden (was it already claimed?)")
  end

  def stub_simplefin_accounts(fixture = "accounts", status: 200, body: nil)
    stub_request(:get, ACCOUNTS_URL)
      .with(basic_auth: %w[ demo secret ])
      .to_return(status:, body: body || simplefin_fixture(fixture))
  end

  def simplefin_fixture(name)
    file_fixture("simplefin/#{name}.json").read
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include SimplefinTestHelper
end
