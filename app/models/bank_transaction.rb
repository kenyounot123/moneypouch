class BankTransaction < ApplicationRecord
  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"

  delegate :name, to: :bank_account, prefix: true

  scope :matched, -> { where(matched: true) }
  scope :imported, -> { where(matched: false) }

  def remember(categorization)
    bank_account.remember(name_key, categorization)
  end

  def imported?
    !matched?
  end
end
