class Transaction < ApplicationRecord
  include Bankable, Broadcastable, Categorizable, Discardable, Exportable, Importable, Searchable

  belongs_to :user

  normalizes :note, with: ->(note) { note.strip.presence }

  scope :latest, -> { order(occurred_on: :desc, id: :desc) }
  scope :occurred_in, ->(dates) { where(occurred_on: dates) }
  scope :counted, -> { where(transfer: false, excluded: false) }
  scope :money_in, -> { where(amount_in_cents: 0..) }
  scope :money_out, -> { where(amount_in_cents: ...0) }
  scope :spending, -> { counted.and(where(category: Category.spending).or(uncategorized.money_out)) }
  scope :incoming, -> { counted.and(where(category: Category.income).or(uncategorized.money_in)) }
  scope :listed, -> { latest.includes(:category, :bank_transaction) }
  scope :uncategorized, -> { where(category_id: nil, transfer: false) }
  scope :categorized, -> { where.not(category_id: nil) }
  scope :transfers, -> { where(transfer: true) }
  scope :in_category, ->(category) { where(category:) }

  def self.spent
    -spending.sum(:amount_in_cents)
  end

  def self.net
    counted.sum(:amount_in_cents)
  end

  def self.income
    incoming.sum(:amount_in_cents)
  end

  def counted?
    !transfer? && !excluded?
  end

  def money_in?
    !amount_in_cents.negative?
  end

  def categorize(categorization)
    update!(categorization:)
  end

  def categorize_as(category:, transfer:)
    categorize Transaction::Categorization.from(category:, transfer:, categories: user.categories, money_in: money_in?)
  end
end
