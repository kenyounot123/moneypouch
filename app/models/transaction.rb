class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }

  # Relative words in a line ("yesterday", no date) read against the day the row was first stashed,
  # so editing a week-old row keeps its date.
  def stashed_on
    (created_at || Time.current).in_time_zone.to_date
  end

  def discard = update!(discarded_at: Time.current)

  def restore = update!(discarded_at: nil)
end
