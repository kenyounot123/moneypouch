# P6. Money out for one month, everything the Overview draws.
#
# ONE grouped query over the previous and current month:
#   SELECT occurred_on, categories.name, SUM(amount_in_cents), COUNT(*)
#   FROM transactions LEFT JOIN categories ...
#   WHERE <kept> AND amount_in_cents < 0 AND occurred_on BETWEEN prev.first AND month.last
#   GROUP BY occurred_on, categories.name
# At most ~62 days x categories rows. Total, per-day bars, per-category bars,
# the month-over-month comparison, and the row count are all folded from it in
# Ruby, so adding a figure never adds a query.
#
# Overview query budget (<= 6): session + user (Authentication), this, Recent
# (eager_load, one query), sidebar count. Five, one spare.
class Spending
  Share = Data.define(:name, :cents, :share, :fill) # share: whole percent; fill: percent of the largest
  Day = Data.define(:date, :cents, :fill)              # fill: percent of the largest day; nil for future days
  Comparison = Data.define(:delta_cents, :percent, :through) # through: last comparable day of the previous month

  UNCATEGORIZED = "Uncategorized"

  attr_reader :month

  # @param transactions [ActiveRecord::Relation] a kept relation, already scoped to the user
  # @param month [Month]
  def initialize(transactions, month:)
    @month = month
    @rows = load(transactions)
  end

  def total_cents
    raise NotImplementedError # positive number: abs of the summed negatives
  end

  def count
    raise NotImplementedError
  end

  def empty? = count.zero?

  # Largest first. Shares are rounded so they sum to 100 (largest-remainder).
  # @return [Array<Share>]
  def shares
    raise NotImplementedError
  end

  # Every day of the month in order; future days have cents 0 and fill nil.
  # @return [Array<Day>]
  def days
    raise NotImplementedError
  end

  def biggest_day = days.max_by(&:cents)

  # This month to date vs the previous month's days 1..min(today.day, prev.last.day).
  # percent is nil when the previous span spent nothing (no divide by zero on day 1).
  # @return [Comparison]
  def comparison
    raise NotImplementedError
  end

  private

  def load(transactions)
    raise NotImplementedError # transactions.spending.where(occurred_on: month.previous.first..month.last).left_joins(:category).group(...).pluck(...)
  end
end
