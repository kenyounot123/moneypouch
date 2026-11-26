class BankAccount::FormerId < ApplicationRecord
  belongs_to :bank_account
  belongs_to :simplefin_access, class_name: "Simplefin::Access", default: -> { bank_account.simplefin_access }
end
