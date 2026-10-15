module WelcomeHelper
  CHART_HEIGHT = 64

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
