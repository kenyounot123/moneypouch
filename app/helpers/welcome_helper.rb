module WelcomeHelper
  CHART_HEIGHT = 136
  SUMMARY_BAR_HEIGHT = 130
  LABEL_SPAN = 7
  MAX_LABELLED_COLUMNS = 12

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

  def column_height(cents, peak, tallest = CHART_HEIGHT)
    [ (cents * tallest.to_f / peak).round, 4 ].max
  end

  def summary_bar_height(cents, peak)
    column_height(cents, peak, SUMMARY_BAR_HEIGHT)
  end

  def category_color(category, index)
    if category.nil?
      "bg-highlight"
    elsif index.zero?
      "bg-data-strong"
    else
      "bg-data"
    end
  end

  def column_color(column, today_column, tallest_column)
    if column == tallest_column
      "bg-data-strong"
    elsif column == today_column
      "bg-data"
    else
      "bg-data-soft"
    end
  end

  def column_labels(period, columns)
    if columns.size <= MAX_LABELLED_COLUMNS
      columns.keys.map { |column| [ column_label(period, column), 1 ] }
    else
      columns.keys.each_slice(LABEL_SPAN).map { |week| [ column_label(period, week.first), week.size ] }
    end
  end

  def whole_spent(cents)
    number_to_currency((cents.to_d / 100).round, precision: 0)
  end

  def whole_net(cents)
    if cents.negative?
      "−#{whole_spent(-cents)}"
    elsif cents.positive?
      "+#{whole_spent(cents)}"
    else
      whole_spent(0)
    end
  end

  def exact_net(cents)
    if cents.negative?
      "−#{spent(-cents)}"
    elsif cents.positive?
      "+#{spent(cents)}"
    else
      spent(0)
    end
  end

  def total_readout(total)
    "#{period_abbreviation(total.period)}#{" so far" if total.period.current?} · income #{whole_spent total.income} · spent #{whole_spent total.spent}"
  end

  def period_abbreviation(period)
    case period.kind
    when "week" then period.first_day.strftime("%b %-d")
    when "month" then period.first_day.strftime("%b")
    when "year" then period.first_day.strftime("%Y")
    end
  end

  def period_name(period)
    case period.kind
    when "week" then span(period.range)
    when "month" then period.first_day.strftime("%B")
    when "year" then period.first_day.strftime("%Y")
    end
  end

  def segment_color(index)
    case index
    when 0 then "bg-data-strong"
    when 1 then "bg-data"
    else "bg-data-soft"
    end
  end

  def flow_segments(rows)
    rest = rows.drop(2)

    if rest.empty?
      rows
    else
      rows.first(2) + [ [ "#{rest.size} more", rest.sum(&:last) ] ]
    end
  end

  private
    def column_label(period, column)
      if period.unit == :month
        column.strftime("%b")
      else
        short_date(column)
      end
    end
end
