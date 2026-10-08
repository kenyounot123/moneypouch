require "test_helper"

class Simplefin::ClientTest < ActiveSupport::TestCase
  test "claiming a setup token returns the access URL" do
    stub_simplefin_claim

    assert_equal ACCESS_URL, Simplefin::Client.claim(SETUP_TOKEN)
  end

  test "claiming a used token is rejected with copy that says how to recover" do
    stub_simplefin_claim(status: 403)

    error = assert_raises(Simplefin::TokenRejected) { Simplefin::Client.claim(SETUP_TOKEN) }
    assert_equal "This token was already used. Get a new one from SimpleFIN.", error.message
  end

  test "text that is not a setup token is rejected without a request" do
    error = assert_raises(Simplefin::TokenRejected) { Simplefin::Client.claim("coffee 5.50") }

    assert_equal "That isn't a SimpleFIN setup token.", error.message
    assert_not_requested :post, CLAIM_URL
  end

  test "a token that decodes to a plain http URL is rejected" do
    error = assert_raises(Simplefin::TokenRejected) { Simplefin::Client.claim(Base64.strict_encode64("http://example.com/claim")) }

    assert_equal "That isn't a SimpleFIN setup token.", error.message
  end

  test "a claim that times out is unavailable" do
    stub_request(:post, CLAIM_URL).to_timeout

    assert_raises(Simplefin::Unavailable) { Simplefin::Client.claim(SETUP_TOKEN) }
  end

  test "accounts reads every account with its institution and balance" do
    stub_simplefin_accounts

    accounts = client.accounts(since: Time.utc(2026, 10, 1))

    assert_equal [ [ "Demo Savings", "SimpleFIN Savings", "SimpleFIN Bridge", "USD", 11_468_551, nil, 5 ],
                   [ "Demo Checking", "SimpleFIN Checking", "SimpleFIN Bridge", "USD", 2_503_551, nil, 5 ],
                   [ "Demo Empty Account", "SimpleFIN Empty Account", "SimpleFIN Bridge", "USD", 0, nil, 0 ] ],
      accounts.map { |account| [ account.id, account.name, account.institution, account.currency, account.balance_in_cents, account.error_message, account.transactions.size ] }
  end

  test "accounts turns amount strings into cents" do
    stub_simplefin_accounts

    checking = client.accounts(since: Time.utc(2026, 10, 1)).second

    assert_equal [ 256_448, -665, -17_667, -1331, -17_001 ], checking.transactions.map(&:amount_in_cents)
    assert_equal [ "You", "John's Fishin Shack" ], checking.transactions.first(2).map(&:payee)
    assert_equal "Fishing bait", checking.transactions.second.description
  end

  test "accounts asks for one window of posted transactions with basic auth" do
    stub_simplefin_accounts

    client.accounts(since: Time.utc(2026, 10, 1))

    assert_requested :get, "https://beta-bridge.simplefin.org/simplefin/accounts?version=2&start-date=1790812800", basic_auth: %w[ demo secret ]
  end

  test "accounts asks for balances only when told to" do
    stub_simplefin_accounts("balances")

    client.accounts(balances_only: true)

    assert_requested :get, "https://beta-bridge.simplefin.org/simplefin/accounts?version=2&balances-only=1"
  end

  test "each account carries its own error, else its connection's" do
    stub_simplefin_accounts("errlist")

    accounts = client.accounts(since: Time.utc(2026, 10, 1))

    assert_equal({ "Demo Savings" => "Authentication with SimpleFIN Bridge is required.",
                   "Demo Checking" => "Authentication with SimpleFIN Bridge is required.",
                   "Demo Card" => "Could not get transactions for SimpleFIN Credit Card." },
      accounts.to_h { |account| [ account.id, account.error_message ] })
  end

  test "an error for no account or connection is only logged" do
    stub_simplefin_accounts("errlist")
    log = StringIO.new
    logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)

    client.accounts(since: Time.utc(2026, 10, 1))

    assert_includes log.string, "SimpleFIN gen.api: Requested date range exceeds recommended range of 45 days."
  ensure
    Rails.logger = logger
  end

  test "accounts maps a lapsed subscription, revoked access, and outages to errors" do
    { 402 => Simplefin::PaymentRequired, 403 => Simplefin::AccessRevoked, 500 => Simplefin::Unavailable }.each do |status, error|
      stub_simplefin_accounts(status:, body: "")

      assert_raises(error) { client.accounts(since: Time.utc(2026, 10, 1)) }
    end
  end

  test "accounts treats a body that is not JSON as unavailable" do
    stub_simplefin_accounts(body: "<html>maintenance</html>")

    assert_raises(Simplefin::Unavailable) { client.accounts(since: Time.utc(2026, 10, 1)) }
  end

  test "accounts that time out are unavailable" do
    stub_request(:get, ACCOUNTS_URL).to_timeout

    assert_raises(Simplefin::Unavailable) { client.accounts(since: Time.utc(2026, 10, 1)) }
  end

  test "a transaction falls on the day it happened in the user's zone" do
    stub_simplefin_accounts
    payday = client.accounts(since: Time.utc(2026, 10, 1)).first.transactions.first

    assert_equal Date.new(2026, 10, 1), Time.use_zone("America/Los_Angeles") { payday.occurred_on }
    assert_equal Date.new(2026, 10, 2), Time.use_zone("UTC") { payday.occurred_on }
  end

  test "a transaction with only a posted date keeps the bank's UTC day" do
    transaction = Simplefin::Transaction.new(id: "1", amount_in_cents: -100, posted_at: Time.utc(2026, 10, 2), transacted_at: nil, description: "Coffee", payee: nil)

    assert_equal Date.new(2026, 10, 2), Time.use_zone("America/Los_Angeles") { transaction.occurred_on }
  end

  private
    def client
      Simplefin::Client.new(ACCESS_URL)
    end
end
