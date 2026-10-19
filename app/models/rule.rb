class Rule < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  scope :latest, -> { order(updated_at: :desc, id: :desc) }

  def self.with_row_counts
    rules = includes(:category, :user).to_a
    counts = rules.map(&:user).uniq.index_with { |user| user.bank_transactions.count_by_name }

    rules.index_with { |rule| counts.fetch(rule.user).fetch(rule.name_key, 0) }
  end

  def matches?(name)
    name.key == name_key
  end

  def categorization
    Transaction::Categorization.new(category:, transfer:)
  end

  def apply_to_uncategorized
    user.transactions_named(name_key).needing_category.update_all(category_id:, transfer:)
  end
end
