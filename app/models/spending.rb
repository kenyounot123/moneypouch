class Spending
  attr_reader :period

  def initialize(transactions, period)
    @transactions = transactions.spending
    @period = period
  end

  def total
    sums.values.sum
  end

  def categories
    totals = sums.each_with_object(Hash.new(0)) { |((_, category_id), cents), memo| memo[category_id] += cents }
    named = Category.where(id: totals.keys).index_by(&:id)

    totals.select { |_, cents| cents.positive? }
      .map { |category_id, cents| [ named[category_id], cents ] }
      .sort_by { |category, cents| [ -cents, category&.name.to_s.downcase ] }
  end

  def columns
    totals = sums.each_with_object(Hash.new(0)) { |((date, _), cents), memo| memo[period.column_for(date)] += cents }

    period.columns.index_with do |column|
      totals.fetch(column) { 0 unless column > period.today }
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
