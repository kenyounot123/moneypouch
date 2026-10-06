class User < ApplicationRecord
  has_secure_password

  validates :username, presence: true, uniqueness: true

  has_many :sessions, dependent: :destroy

  has_one :bank_integration

  has_many :transactions, -> { kept }
  has_many :discarded_transactions, -> { discarded }, class_name: "Transaction"
  has_many :categories, dependent: :destroy
end
