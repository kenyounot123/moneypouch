class Summary
  MONTHS = 6

  Total = Data.define(:month, :income, :spent) do
    def net
      income - spent
    end
  end

  def initialize(transactions, today:)
    @transactions = transactions
    @today = today
  end

  def months
    @months ||= (0...MONTHS).map { |ago| month_ago(ago) }.reverse
  end

  def totals
    totals_for(months)
  end

  def total(month)
    totals_for([ month ]).first
  end

  def sources(month)
    @transactions.incoming.occurred_in(month.range)
      .group(:name)
      .sum(:amount_in_cents)
      .select { |_, cents| cents.positive? }
      .sort_by { |name, cents| [ -cents, name.downcase ] }
  end

  def categories(month)
    Spending.new(@transactions, month).categories
  end

  private
    def month_ago(ago)
      month = Month.new(nil, today: @today)

      ago.times do
        month = month.previous
      end

      month
    end

    def totals_for(months)
      range = months.first.first_day..months.last.range.end
      income = by_month(@transactions.incoming, range)
      spent = by_month(@transactions.spending, range).transform_values(&:-@)

      months.map do |month|
        Total.new(month:, income: income.fetch(month.first_day, 0), spent: spent.fetch(month.first_day, 0))
      end
    end

    def by_month(scope, range)
      scope.occurred_in(range)
        .group(:occurred_on)
        .sum(:amount_in_cents)
        .each_with_object(Hash.new(0)) { |(date, cents), memo| memo[date.beginning_of_month] += cents }
    end
end
