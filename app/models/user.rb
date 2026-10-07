class User < ApplicationRecord
  has_secure_password

  validates :username, presence: true, uniqueness: true

  has_many :sessions, dependent: :destroy

  has_many :transactions, -> { kept }
  has_many :discarded_transactions, -> { discarded }, class_name: "Transaction"
  has_many :categories, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy

  has_one :simplefin_access, class_name: "Simplefin::Access", dependent: :destroy

  def connect_simplefin(setup_token)
    (simplefin_access || build_simplefin_access).tap do |access|
      access.connect(setup_token)
    end
  end
end
