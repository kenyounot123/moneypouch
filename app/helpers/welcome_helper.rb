module WelcomeHelper
  CHART_HEIGHT = 64

  def transactions_total(count, since)
    "#{number_with_delimiter(count)} #{"transaction".pluralize(count)} since #{since.strftime("%b %Y")}"
  end

  def spent_heading(period)
    case period.kind
    when "week" then "Spent this week"
    when "month" then "Spent in #{period.today.strftime("%B")}"
    when "year" then "Spent in #{period.today.year}"
    end
  end

  def nothing_spent(period)
    if period.kind == "year"
      "Nothing spent in #{period.today.year}."
    else
      "Nothing spent this #{period.kind}."
    end
  end

  def spent(cents)
    number_to_currency(cents.to_d / 100)
  end

  def span(dates)
    first, last = dates.begin, dates.end
    label =
      if first == last
        first.strftime("%b %-d")
      elsif first.month == last.month && first.year == last.year
        "#{first.strftime("%b %-d")}–#{last.day}"
      else
        "#{first.strftime("%b %-d")}–#{last.strftime("%b %-d")}"
      end

    if last.year == Date.current.year
      label
    else
      "#{label}, #{last.year}"
    end
  end

  def spending_change(spending)
    before = spending.previous_total
    return if before.zero?

    difference = spending.elapsed_total - before
    against = span(spending.period.previous.elapsed)

    if difference.zero?
      "Same as #{against}"
    else
      arrow = difference.negative? ? "↓" : "↑"
      dollars = number_to_currency(difference.abs.to_d / 100, precision: difference.abs < 1_000 ? 2 : 0)
      percent = number_to_percentage(difference.abs * 100.0 / before, precision: 1, delimiter: ",", strip_insignificant_zeros: true)
      "#{arrow} #{dollars} (#{percent}) vs. #{against}"
    end
  end

  def spending_peak(transaction)
    cents = transaction.amount_in_cents.abs
    amount = number_to_currency(cents.to_d / 100, precision: (cents % 100).zero? ? 0 : 2)

    "#{short_date(transaction.occurred_on)} #{transaction.name} · #{amount}"
  end

  def share_of(cents, total)
    percent = (cents * 100.0 / total).round

    if percent.zero?
      "<1%"
    else
      "#{percent}%"
    end
  end

  def column_title(period, column, cents)
    if period.unit == :month
      "#{column.strftime("%B")} · #{spent cents}"
    else
      "#{short_date column} · #{spent cents}"
    end
  end

  def column_height(cents, peak)
    [ (cents * CHART_HEIGHT.to_f / peak).round, 4 ].max
  end
end
