class BankTransaction < ApplicationRecord
  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"

  delegate :name, to: :bank_account, prefix: true

  scope :imported, -> { where(matched: false) }

  def self.count_by_name
    imported.where(transaction_id: Transaction.kept.select(:id)).group(:name_key).count
  end

  def name
    BankTransaction::Name.new(payee:, description:)
  end

  def imported?
    !matched?
  end
end
