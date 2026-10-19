class Category < ApplicationRecord
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

  validates :name, presence: true

  def named?(other_name)
    name.downcase(:ascii) == other_name.downcase(:ascii)
  end
end
