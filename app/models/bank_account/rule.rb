class BankAccount::Rule < ApplicationRecord
  belongs_to :bank_account
  belongs_to :category, optional: true

  def matches?(name)
    name.key == name_key
  end

  def categorization
    Transaction::Categorization.new(category:, transfer:)
  end

  def apply_to_uncategorized
    bank_account.transactions_named(name_key).needing_category.update_all(category_id:, transfer:)
  end
end
