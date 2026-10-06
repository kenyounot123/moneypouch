require "net/http"

class Simplefin::Client
  NOT_A_TOKEN = "That isn't a SimpleFIN setup token."
  TOKEN_USED = "This token was already used. Get a new one from SimpleFIN."
  UNREACHABLE = "SimpleFIN didn't answer. Try again in a minute."

  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError ].freeze
  HTTP_OPTIONS = { use_ssl: true, open_timeout: 10, read_timeout: 60 }.freeze

  class << self
    def claim(setup_token)
      url = claim_url(setup_token)
      response = Net::HTTP.start(url.host, url.port, **HTTP_OPTIONS) { |http| http.request(Net::HTTP::Post.new(url)) }

      case response
      when Net::HTTPSuccess
        response.body.strip
      when Net::HTTPForbidden
        raise Simplefin::TokenRejected, TOKEN_USED
      else
        raise Simplefin::Unavailable, UNREACHABLE
      end
    rescue *NETWORK_ERRORS
      raise Simplefin::Unavailable, UNREACHABLE
    end

    private
      def claim_url(setup_token)
        url = URI(Base64.strict_decode64(setup_token.to_s.strip))

        if url.is_a?(URI::HTTPS)
          url
        else
          raise Simplefin::TokenRejected, NOT_A_TOKEN
        end
      rescue ArgumentError, URI::InvalidURIError
        raise Simplefin::TokenRejected, NOT_A_TOKEN
      end
  end

  def initialize(access_url)
    @access_url = URI(access_url)
  end

  def accounts(since: nil, balances_only: false)
    url = accounts_url(since:, balances_only:)
    response = Net::HTTP.start(url.host, url.port, **HTTP_OPTIONS) { |http| http.request(accounts_request(url)) }

    case response
    when Net::HTTPSuccess
      parse_accounts(JSON.parse(response.body))
    when Net::HTTPPaymentRequired
      raise Simplefin::PaymentRequired
    when Net::HTTPForbidden
      raise Simplefin::AccessRevoked
    else
      raise Simplefin::Unavailable, UNREACHABLE
    end
  rescue JSON::ParserError, *NETWORK_ERRORS
    raise Simplefin::Unavailable, UNREACHABLE
  end

  private
    def accounts_request(url)
      Net::HTTP::Get.new(url).tap do |request|
        request.basic_auth(URI.decode_www_form_component(@access_url.user), URI.decode_www_form_component(@access_url.password))
      end
    end

    def accounts_url(since:, balances_only:)
      @access_url.dup.tap do |url|
        url.userinfo = nil
        url.path = "#{@access_url.path}/accounts"
        url.query = URI.encode_www_form({ "version" => 2, "start-date" => since&.to_i, "balances-only" => (1 if balances_only) }.compact)
      end
    end

    def parse_accounts(body)
      institutions = body.fetch("connections", []).to_h { |connection| [ connection["conn_id"], connection["org_name"] ] }
      errors = body.fetch("errlist", [])
      log_general_errors(errors)

      body.fetch("accounts").map do |account|
        Simplefin::Account.new(
          id: account.fetch("id"),
          name: account.fetch("name"),
          institution: institutions[account["conn_id"]],
          currency: account.fetch("currency"),
          balance_in_cents: cents(account["balance"]),
          error_message: error_message_for(account, errors),
          transactions: account.fetch("transactions", []).map { |transaction| parse_transaction(transaction) }
        )
      end
    end

    def log_general_errors(errors)
      errors.each do |error|
        if error["account_id"].nil? && error["conn_id"].nil?
          Rails.logger.info "SimpleFIN #{error["code"]}: #{error["msg"]}"
        end
      end
    end

    def error_message_for(account, errors)
      error = errors.find { |error| error["account_id"] == account.fetch("id") } ||
        errors.find { |error| error["account_id"].nil? && error["conn_id"] == account["conn_id"] }

      error&.fetch("msg", nil)
    end

    def parse_transaction(transaction)
      Simplefin::Transaction.new(
        id: transaction.fetch("id"),
        amount_in_cents: cents(transaction.fetch("amount")),
        posted_at: Time.zone.at(transaction.fetch("posted")),
        transacted_at: transaction["transacted_at"]&.then { |epoch| Time.zone.at(epoch) },
        description: transaction.fetch("description"),
        payee: transaction["payee"].presence
      )
    end

    def cents(amount)
      if amount
        (BigDecimal(amount) * 100).round(0, half: :even).to_i
      end
    end
end
