class Summary
  PERIODS = 6

  Total = Data.define(:period, :income, :spent) do
    def net
      income - spent
    end
  end

  def initialize(transactions, period)
    @transactions = transactions
    @period = period
  end

  def periods
    @periods ||= (1...PERIODS).each_with_object([ @period ]) { |_, periods| periods.unshift(periods.first.previous) }
  end

  def totals
    totals_for(periods)
  end

  def total(period)
    totals_for([ period ]).first
  end

  def sources(period)
    @transactions.incoming.occurred_in(period.range)
      .group(:name)
      .sum(:amount_in_cents)
      .select { |_, cents| cents.positive? }
      .sort_by { |name, cents| [ -cents, name.downcase ] }
  end

  def categories(period)
    Spending.new(@transactions, period).categories
  end

  private
    def totals_for(periods)
      range = periods.first.first_day..periods.last.range.end
      income = by_period(@transactions.incoming, periods, range)
      spent = by_period(@transactions.spending, periods, range).transform_values(&:-@)

      periods.map do |period|
        Total.new(period:, income: income.fetch(period, 0), spent: spent.fetch(period, 0))
      end
    end

    def by_period(scope, periods, range)
      scope.occurred_in(range)
        .group(:occurred_on)
        .sum(:amount_in_cents)
        .each_with_object(Hash.new(0)) { |(date, cents), memo| memo[periods.find { |period| period.range.cover?(date) }] += cents }
    end
end
