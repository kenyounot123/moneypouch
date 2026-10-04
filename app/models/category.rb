class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :nullify

  normalizes :name, with: ->(name) { name.squish }

  # downcase(:ascii) agrees with the lower(name) index, since SQLite lower() folds ASCII only.
  scope :named, ->(name) { where("lower(name) = ?", name.downcase(:ascii)) }

  validates :name, presence: true
end
