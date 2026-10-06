class Spending
  attr_reader :period

  def initialize(transactions, period)
    @transactions = transactions.spending
    @period = period
  end

  def total
    sums.values.sum
  end

  def elapsed_total
    sums.sum { |(date, _), cents| date <= period.today ? cents : 0 }
  end

  def previous_total
    -@transactions.occurred_in(period.previous.elapsed).sum(:amount_in_cents)
  end

  def categories
    totals = sums.each_with_object(Hash.new(0)) { |((_, category_id), cents), memo| memo[category_id] += cents }
    named = Category.where(id: totals.keys).index_by(&:id)

    totals.map { |category_id, cents| [ named[category_id], cents ] }
      .sort_by { |category, cents| [ -cents, category&.name.to_s.downcase ] }
  end

  def columns
    totals = sums.each_with_object(Hash.new(0)) { |((date, _), cents), memo| memo[period.column_for(date)] += cents }

    period.columns.index_with do |column|
      totals.fetch(column) { 0 unless column > period.today }
    end
  end

  def peak
    column, cents = columns.max_by { |_, cents| cents.to_i }

    if cents.to_i.positive?
      @transactions.occurred_in(period.column_range(column)).order(:amount_in_cents, :id).first
    end
  end

  private
    def sums
      @sums ||= @transactions.occurred_in(period.range)
        .group(:occurred_on, :category_id)
        .sum(:amount_in_cents)
        .transform_values(&:-@)
    end
end
