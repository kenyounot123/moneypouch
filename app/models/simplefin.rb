module Simplefin
  class Error < StandardError; end
  class TokenRejected < Error; end
  class PaymentRequired < Error; end
  class AccessRevoked < Error; end
  class Unavailable < Error; end

  def self.table_name_prefix
    "simplefin_"
  end
end
