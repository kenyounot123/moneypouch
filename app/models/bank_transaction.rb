class BankTransaction < ApplicationRecord
  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"

  delegate :name, to: :bank_account, prefix: true

  scope :matched, -> { where(matched: true) }
  scope :imported, -> { where(matched: false) }

  def self.count_by_account_and_name
    imported.where(transaction_id: Transaction.kept.select(:id)).group(:bank_account_id, :name_key).count
  end

  def remember(categorization)
    bank_account.remember(name, categorization)
  end

  def remembers?(categorization)
    bank_account.remembers?(name_key, categorization)
  end

  def namesakes
    bank_account.transactions_named(name_key)
  end

  def name
    BankTransaction::Name.new(payee:, description:)
  end

  def imported?
    !matched?
  end
end
