class BankIntegration::Simplefin
  attr_accessor :base_url

  def self.create_url
    "https://bridge.simplefin.org/simplefin/create"
  end

  def initialize(user)
    @user = user
    @base_url = nil
  end

  def setup
    simplefin_access_url = get_access_url
    user.update(simplefin_access_url: simplefin_access_url)
  end

  def accounts
    return unless user.simplefin_access_url
    account_and_transaction_data # this can raise
  end

  private
    def get_access_url
      url = decode_setup_token
      response = Net::HTTP.post(URI(url), nil)

      if response.is_a?(Net::HTTPSuccess)
        @base_url = response.body
      else
        @base_url = nil
      end

      @base_url
    end

    def decode_setup_token
      Base64.decode64(user.simplefin_setup_token)
    end

    def account_and_transaction_data
      return unless @base_url

      uri = URI("#{@base_url}/accounts")
      uri.query = URI.encode_www_form(
        "pending" => 1,
        "start-date" => 90.days.ago.to_i,
        "version" => 2
      )
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(uri.user, uri.password)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      case repsponse
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPPaymentRequired
        "do something"
      when Net::HTTPForbidden
        "do something"
      else
        raise
      end
    end
end
