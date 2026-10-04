# One money movement. amount_in_cents is signed: negative = money out (SimpleFIN).
#
# One read verb and one write verb, both anchored on the same day:
#   transaction.draft(line)  -> Draft, never writes     (preview)
#   transaction.stash(line)  -> Boolean, saves          (create, edit, undo of an edit)
# Both read the line against `stashed_on`, so a preview cannot disagree with its save,
# and re-reading a row's own `line` reproduces the row exactly.
#
# Lifecycle, each transition reachable only from its source state:
#   user.transactions (kept) --discard--> user.discarded_transactions --restore--> kept
class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }
  scope :spending, -> { where(amount_in_cents: ...0) }
  scope :during, ->(month) { where(occurred_on: month.dates) }
  # Overview Recent: newest stash on top, not newest date.
  scope :latest_stashed, -> { order(id: :desc) }
  # Month list: by day, then newest stash within the day.
  scope :by_day, -> { order(occurred_on: :desc, id: :desc) }

  # P5. Reads the line as of the day this transaction was first stashed.
  # @return [Draft]
  def draft(line)
    Draft.parse(line, user:, today: stashed_on, excluding: (self if persisted?))
  end

  # P5/P9. Parses, assigns, saves. A first-use category is built unsaved by Draft
  # and autosaved by belongs_to inside this save's DB transaction.
  # @return [Boolean] false with errors[:base] = the draft's first error
  def stash(line)
    draft = draft(line)
    raise NotImplementedError
    # if draft.errors.any? then errors.add(:base, draft.errors.first); return false
    # assign_attributes(draft.attributes); save
    # rescue ActiveRecord::RecordNotUnique on categories: a concurrent first use
    #   created it between parse and save; retry once (the re-parse finds it).
  end

  # P3. The anchor for relative words ("yesterday", "friday", no date).
  # New record: today in the request's zone. Persisted: the day it was created,
  # so editing `coffee 5 yesterday` a week later keeps its date, and undo of an
  # edit (PATCH with the previous line) restores the exact previous row.
  def stashed_on
    (created_at || Time.current).in_time_zone.to_date
  end

  # P9. What `e` loads into the bar. Rows from before P5 have no line, so one is
  # composed that reads back to this row: name, amount, ISO date, #category.
  def editable_line
    raise NotImplementedError
  end

  def money_in? = amount_in_cents.positive?

  def discard = update!(discarded_at: Time.current)

  def restore = update!(discarded_at: nil)
end
