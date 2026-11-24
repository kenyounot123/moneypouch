class Transaction::DuplicateAnswer < ApplicationRecord
  self.table_name = "duplicate_answers"

  belongs_to :typed_transaction, class_name: "Transaction"
  belongs_to :bank_transaction

  scope :same, -> { where(same: true) }
  scope :different, -> { where(same: false) }
end
