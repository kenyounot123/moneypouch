# P4. A typed line, read for one user. The only code that decides what a line means.
#
#   Draft.parse("coffee 5.50 yesterday", user:, today: Date.new(2026, 9, 27)).attributes
#   # => { name: "coffee", amount_in_cents: -550, occurred_on: 2026-09-26,
#   #      category: #<Category Food>, line: "coffee 5.50 yesterday" }
#
# Two layers, one file (P4 touches only this file and its test):
#   Grammar   pure: String + today -> Reading. No user, no DB, no clock. Every
#             grammar test runs here with a literal line and a fixed today.
#   Draft     Reading + user -> resolved Category. At most ONE indexed query per
#             parse: the `#word` lookup or the history inference, never both.
#
# Never writes. A first-use category comes back unsaved, so the caller's save
# persists it atomically with the transaction (belongs_to autosave).
class Draft
  MISSING_AMOUNT = "Add an amount"
  MISSING_NAME = "Add a name"

  # Pure result of the grammar. category_word is the `#word` minus `#`, or nil.
  Reading = Data.define(:name, :amount_in_cents, :category_word, :occurred_on, :errors)

  module Grammar
    # Token rules, applied in this order so `sep 26 rent 1650` reads 26 as a day,
    # not the amount. Each rule consumes the FIRST match only; later look-alikes
    # stay in the name ("7 eleven 5" -> amount 7, name "eleven 5").
    #   1. month-name + day   "sep 26", "sept 26", "september 26" (needs both tokens)
    #   2. numeric date       "9/26", "2026-09-26"
    #   3. relative word      "today", "yesterday", full weekday names only
    #                         (abbreviations collide with names: "sat", "sun", "wed")
    #   4. category           "#word"
    #   5. amount             /\A(\+)?\$?(\d+)(?:\.(\d{1,2}))?\z/, "+" = money in
    #   6. remaining words, joined by one space = name (original casing kept)
    #
    # Date resolution against `today`:
    #   weekday     latest on or before today (same weekday = today)
    #   month/day   latest occurrence on or before today ("dec 30" on 2027-01-02 -> 2026-12-30)
    #   impossible  "feb 30", "13/40": not a date, the token stays in the name
    #
    # @param line [String]
    # @param today [Date]
    # @return [Reading]
    def self.read(line, today:)
      raise NotImplementedError
    end
  end

  # @param line [String] the line as typed
  # @param user [User] scope for category lookup and inference
  # @param today [Date] anchor for relative dates; never read from the clock here
  # @param excluding [Transaction, nil] the row being edited, left out of inference
  #   so editing a row cannot infer its category from itself
  # @return [Draft]
  def self.parse(line, user:, today:, excluding: nil)
    reading = Grammar.read(line.to_s, today:)
    new(line: line.to_s, reading:, category: resolve_category(reading, user, excluding))
  end

  # `#word`: the user's category matching ignoring ASCII case, else a new unsaved one.
  # No `#word`: the category of the user's latest kept transaction with the same
  # name ignoring case (index_transactions_on_user_id_and_lower_name_kept), else nil.
  # Skipped when the line has errors. user.transactions is kept-only by construction.
  def self.resolve_category(reading, user, excluding)
    raise NotImplementedError
    # if reading.category_word
    #   user.categories.named(reading.category_word).first || user.categories.new(name: reading.category_word)
    # elsif reading.name.present?
    #   user.transactions.where("lower(name) = ?", reading.name.downcase(:ascii))
    #     .where.not(id: excluding&.id).order(occurred_on: :desc, id: :desc).first&.category
    # end
  end
  private_class_method :resolve_category

  attr_reader :line, :category

  def initialize(line:, reading:, category:)
    @line = line
    @reading = reading
    @category = category
  end

  delegate :name, :amount_in_cents, :occurred_on, :errors, to: :@reading

  def category_name = category&.name

  # True when the category came from history, not a `#word`. The read-back says "(like last time)".
  def inferred? = category.present? && @reading.category_word.nil?

  def valid? = errors.empty?

  def money_in? = amount_in_cents.to_i.positive?

  # The hash Transaction assigns. Only meaningful when valid?.
  def attributes
    { name:, amount_in_cents:, occurred_on:, category:, line: }
  end

  # `render draft` -> drafts/_draft.html.erb (the pills, or the first error).
  def to_partial_path = "drafts/draft"
end
