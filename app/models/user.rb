class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_one :bank_integration
  has_many :transactions
end
