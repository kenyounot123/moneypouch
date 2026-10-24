class Trends
  MONTHS = 12
  FULL_MONTHS_NEEDED = 2
  USUAL_MONTHS = 6
  REGULAR_MONTHS = 3
  CHARGE_AMOUNT_SPREAD = 0.2
  CHARGE_STOPPED_AFTER = 45

  Month = Data.define(:month, :income, :spent) do
    def net
      income - spent
    end

    def positive_net
      net if net.positive?
    end

    def partial?
      month.current?
    end
  end

  # series maps each of the 12 months to cents. usual is the median of the 6 full months before this one,
  # counting empty months, and stays nil until the category has money in at least 2 of them.
  Line = Data.define(:category, :series, :current, :usual) do
    def label
      category&.name || "Uncategorized"
    end

    def total
      series.values.sum
    end
  end

  # A charge that comes about once a month under the same name. amount is the latest one, and previous_amount
  # the one before it when that was different.
  Recurring = Data.define(:name, :amount, :previous_amount, :day, :last_on)

  # days are the days of the month it usually arrives on, those it arrived on in at least 3 different months.
  Source = Data.define(:name, :total, :days, :first_on)

  Entry = Data.define(:on, :category_id, :name, :cents)
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

  def current
    periods.last
  end

  def last_full
    periods[-2]
  end

  def notes
    @notes ||= Notes.for(self)
  end

  def recurring
    charges.select { |charge| charge.last_on >= today - CHARGE_STOPPED_AFTER }
  end

  def stopped
    charges - recurring
  end

  def recurring_total
    recurring.sum(&:amount)
  end

  def sources
    @sources ||= income_entries.group_by { |entry| entry.name.downcase }
      .filter_map { |_, rows| source_from(rows) }
      .sort_by { |source| [ -source.total, source.name.downcase ] }
  end

  def spending_lines
    @spending_lines ||= lines_from(spending_series)
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

  def positive_net
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
        .pluck(:occurred_on, :category_id, :name, :amount_in_cents)
        .map { |on, category_id, name, cents| Entry.new(on:, category_id:, name:, cents: cents * sign) }
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

    def charges
      @charges ||= spending_entries.group_by { |entry| entry.name.downcase }
        .filter_map { |_, rows| recurring_from(rows.sort_by(&:on)) }
        .sort_by { |charge| [ -charge.amount, charge.name.downcase ] }
    end

    def recurring_from(rows)
      months = rows.map { |row| row.on.beginning_of_month }.uniq.size
      typical = median(rows.map(&:cents))
      steady = typical.positive? && rows.all? { |row| (row.cents - typical).abs <= typical * CHARGE_AMOUNT_SPREAD }

      if months >= REGULAR_MONTHS && rows.size <= months && steady
        latest, before = rows.last, rows[-2]
        Recurring.new(name: latest.name, amount: latest.cents, previous_amount: (before.cents unless before.cents == latest.cents),
          day: median(rows.map { |row| row.on.day }), last_on: latest.on)
      end
    end

    def source_from(rows)
      total = rows.sum(&:cents)

      if total.positive?
        days = rows.group_by { |row| row.on.day }.select { |_, same_day| same_day.map { |row| row.on.beginning_of_month }.uniq.size >= REGULAR_MONTHS }.keys.sort
        Source.new(name: rows.max_by(&:on).name, total:, days:, first_on: rows.map(&:on).min)
      end
    end

    def lines_from(all_series)
      categories = Category.where(id: all_series.keys.compact).index_by(&:id)

      all_series.map { |category_id, series| Line.new(category: categories[category_id], series:, current: series.fetch(current), usual: usual_of(series)) }
        .sort_by { |line| [ -line.total, line.label.downcase ] }
    end

    def usual_of(series)
      recent = periods[0...-1].last(USUAL_MONTHS).map { |period| series.fetch(period) }
      median(recent) if recent.count(&:positive?) >= 2
    end

    def median(values)
      sorted = values.sort
      middle = sorted.size / 2

      if sorted.size.odd?
        sorted[middle]
      else
        (sorted[middle - 1] + sorted[middle]) / 2
      end
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
