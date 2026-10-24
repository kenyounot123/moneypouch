class Category < ApplicationRecord
  # Money in with no category of its own lands here, so it keeps its name and can't be merged away or deleted.
  INCOME = "Income"

  belongs_to :user
  belongs_to :import, optional: true
  has_many :transactions, dependent: :nullify
  has_many :rules

  normalizes :name, with: ->(name) { name.squish }

  # downcase(:ascii) agrees with the lower(name) index, since SQLite lower() folds ASCII only.
  scope :named, ->(name) { where("lower(name) = ?", name.downcase(:ascii)) }
  scope :alphabetically, -> { order(Arel.sql("lower(name)")) }
  scope :unused, -> { where.missing(:transactions, :rules) }
  scope :income, -> { where(income: true) }
  scope :spending, -> { where(income: false) }
  scope :default_income, -> { income.named(INCOME) }
  scope :changeable, -> { where.not(id: default_income) }

  validates :name, presence: true

  def named?(other_name)
    name.downcase(:ascii) == other_name.downcase(:ascii)
  end

  def default_income?
    income? && named?(INCOME)
  end

  # Another category's name trips the lower(name) index, not a validation.
  def revise(attributes)
    Transaction.broadcasting_once_for(user) { update(attributes) }
  rescue ActiveRecord::RecordNotUnique
    errors.add(:base, "#{name} is already a category. Merge into it instead.")
    false
  end

  # Moves every transaction, deleted ones too, and every rule onto the other category, then drops this one.
  def merge_into(other)
    if other == self || other.user != user
      raise ArgumentError, "a category merges into another category of the same user"
    end

    Transaction.broadcasting_once_for(user) do
      transaction do
        transactions.update_all(category_id: other.id, updated_at: Time.current)
        rules.update_all(category_id: other.id, updated_at: Time.current)
        destroy!
      end
    end
  end

  # Its transactions become uncategorized, and the database drops its rules.
  def remove
    Transaction.broadcasting_once_for(user) { destroy! }
  end
end
