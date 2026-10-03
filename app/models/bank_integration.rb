require "net/http"

class BankIntegration < ApplicationRecord
  belongs_to :user

  SERVICES = %w[ simplefin ]

  def self.connect(service:)
    BankIntegration::Simplefin.new(user).setup
  end
end
