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
    @totals ||= months.map do |month|
      Total.new(month:, income: income_by_month.fetch(month.first_day, 0), spent: spent_by_month.fetch(month.first_day, 0))
    end
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

    def range
      months.first.first_day..months.last.range.end
    end

    def income_by_month
      @income_by_month ||= by_month(@transactions.incoming)
    end

    def spent_by_month
      @spent_by_month ||= by_month(@transactions.spending).transform_values(&:-@)
    end

    def by_month(scope)
      scope.occurred_in(range)
        .group(:occurred_on)
        .sum(:amount_in_cents)
        .each_with_object(Hash.new(0)) { |(date, cents), memo| memo[date.beginning_of_month] += cents }
    end
end
