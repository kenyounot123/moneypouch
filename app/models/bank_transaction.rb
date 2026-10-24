class BankTransaction < ApplicationRecord
  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"

  delegate :full_name, to: :bank_account, prefix: true

  scope :unmatched, -> { where(matched: false) }

  def self.count_by_name
    unmatched.where(transaction_id: Transaction.kept.select(:id)).group(:name_key).count
  end

  def name
    BankTransaction::Name.new(payee:, description:)
  end

  def unmatched?
    !matched?
  end
end
