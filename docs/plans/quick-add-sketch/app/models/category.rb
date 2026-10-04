# P3. A user's label for spending, created the first time a line uses `#word`.
# Keeps the casing of first use: `#food` after `#Food` resolves to "Food".
class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :nullify

  normalizes :name, with: ->(name) { name.squish }

  # Case-insensitive match that agrees with the lower(name) index (ASCII fold).
  scope :named, ->(name) { where("lower(name) = ?", name.downcase(:ascii)) }

  validates :name, presence: true
end
