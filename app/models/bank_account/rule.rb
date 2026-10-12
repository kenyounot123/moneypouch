class BankAccount::Rule < ApplicationRecord
  belongs_to :bank_account
  belongs_to :category, optional: true

  delegate :name, to: :bank_account, prefix: true

  scope :latest, -> { order(updated_at: :desc, id: :desc) }

  def self.with_row_counts
    rules = includes(:category, :bank_account).to_a
    rows = BankTransaction.where(bank_account: rules.map(&:bank_account)).count_by_account_and_name

    rules.index_with { |rule| rows.fetch([ rule.bank_account_id, rule.name_key ], 0) }
  end

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
