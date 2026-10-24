class Trends
  MONTHS = 12
  FULL_MONTHS_NEEDED = 2

  Month = Data.define(:month, :income, :spent) do
    def net
      income - spent
    end

    def kept
      net if net.positive?
    end

    def partial?
      month.current?
    end
  end

  Entry = Data.define(:on, :category_id, :cents)
  private_constant :Entry

  attr_reader :today

  def initialize(transactions, today:)
    @transactions = transactions
    @today = today
  end

  # The 12 calendar months ending with the current one, oldest first.
  def periods
    @periods ||= (1...MONTHS).each_with_object([ Period.new("month", today:) ]) { |_, periods| periods.unshift(periods.first.previous) }
  end

  def months
    @months ||= periods.map do |period|
      Month.new(month: period, income: total_in(income_series, period), spent: total_in(spending_series, period))
    end
  end

  def income
    months.sum(&:income)
  end

  def spent
    months.sum(&:spent)
  end

  def kept
    net = income - spent
    net if net.positive?
  end

  def full_months_with_data
    @full_months_with_data ||= (spending_entries + income_entries).map { |entry| period_of(entry.on) }.uniq.count { |period| !period.current? }
  end

  def ready?
    full_months_with_data >= FULL_MONTHS_NEEDED
  end

  private
    def spending_entries
      @spending_entries ||= entries(@transactions.spending, sign: -1)
    end

    def income_entries
      @income_entries ||= entries(@transactions.incoming, sign: 1)
    end

    def entries(scope, sign:)
      scope.occurred_in(periods.first.first_day..periods.last.range.end)
        .pluck(:occurred_on, :category_id, :amount_in_cents)
        .map { |on, category_id, cents| Entry.new(on:, category_id:, cents: cents * sign) }
    end

    def spending_series
      @spending_series ||= series_by_category(spending_entries)
    end

    def income_series
      @income_series ||= series_by_category(income_entries)
    end

    # A refund can outweigh a month's spending, and that month then reads as nothing spent instead of negative money.
    def series_by_category(entries)
      entries.group_by(&:category_id)
        .transform_values do |rows|
          series = periods.index_with(0)
          rows.each { |row| series[period_of(row.on)] += row.cents }
          series.transform_values { |cents| [ cents, 0 ].max }
        end
        .select { |_, series| series.values.any?(&:positive?) }
    end

    def total_in(all_series, period)
      all_series.each_value.sum { |series| series.fetch(period) }
    end

    def period_of(date)
      periods_by_start.fetch(date.beginning_of_month)
    end

    def periods_by_start
      @periods_by_start ||= periods.index_by(&:first_day)
    end
end
