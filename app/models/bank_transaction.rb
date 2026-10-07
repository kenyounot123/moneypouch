class BankTransaction < ApplicationRecord
  belongs_to :bank_account
  belongs_to :simplefin_sync, class_name: "Simplefin::Sync"

  scope :matched, -> { where(matched: true) }
  scope :imported, -> { where(matched: false) }
end
