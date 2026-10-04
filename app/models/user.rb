class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_one :bank_integration

  # Kept-only, so no read through a user can count a discarded row.
  has_many :transactions, -> { kept }
  has_many :discarded_transactions, -> { discarded }, class_name: "Transaction"
  has_many :categories, dependent: :destroy
end
