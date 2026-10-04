class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_one :bank_integration

  # P3. Kept by construction: every read through `user.transactions` (totals,
  # inference, completions, Recent, the month list, update and destroy lookups)
  # cannot see a discarded row. Only Transactions::RestorationsController reaches
  # the discarded side. Appendix C's leak risk becomes structural, not grep-audited.
  has_many :transactions, -> { kept }
  has_many :discarded_transactions, -> { discarded }, class_name: "Transaction"
  has_many :categories, dependent: :destroy
end
