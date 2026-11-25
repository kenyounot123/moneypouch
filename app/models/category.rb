class Category < ApplicationRecord
  INCOME = "Income"

  belongs_to :user
  belongs_to :import, optional: true
  has_many :transactions, dependent: :nullify
  has_many :rules

  normalizes :name, with: ->(name) { name.squish }

  scope :named, ->(name) { where("lower(name) = ?", folded_like_sqlite_lower(name)) }
  scope :alphabetically, -> { order(Arel.sql("lower(name)")) }
  scope :unused, -> { where.missing(:transactions, :rules) }
  scope :income, -> { where(income: true) }
  scope :spending, -> { where(income: false) }
  scope :excluded, -> { where(excluded: true) }
  scope :default_income, -> { income.named(INCOME) }
  scope :changeable, -> { where.not(id: default_income) }

  validates :name, presence: true

  def self.folded_like_sqlite_lower(name)
    name.downcase(:ascii)
  end

  def named?(other_name)
    name.downcase(:ascii) == other_name.downcase(:ascii)
  end

  def default_income?
    income? && named?(INCOME)
  end

  def revise(attributes)
    Transaction.broadcasting_once_for(user) { update(attributes) }
  rescue ActiveRecord::RecordNotUnique
    errors.add(:base, "#{name} is already a category. Merge into it instead.")
    false
  end

  def exclude
    Transaction.broadcasting_once_for(user) { update!(excluded: true) }
  end

  def include_in_totals
    Transaction.broadcasting_once_for(user) { update!(excluded: false) }
  end

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

  def remove
    Transaction.broadcasting_once_for(user) { destroy! }
  end
end
