module WelcomeHelper
  PLOT_HEIGHT = 140
  MAX_TICKS = 5
  ROUND_STEPS = [ 1, 2, 2.5, 5, 10 ]
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

  Readout = Data.define(:heading, :amount, :detail, :tone) do
    def params
      { chart_heading_param: heading, chart_amount_param: amount, chart_detail_param: detail.to_s, chart_tone_param: tone.to_s }
    end
  end

  def column_readout(period, column, cents)
    heading =
      if period.unit == :month
        "Spent in #{column.strftime("%B")}"
      elsif column == period.today
        "Spent today"
      else
        "Spent on #{short_date column}"
      end

    Readout.new(heading:, amount: money(cents.to_i), detail: nil, tone: nil)
  end

  def net_readout(total)
    tone = total.net.negative? ? "overspent" : "saved"
    heading = "#{tone.capitalize} #{"in " unless total.period.kind == "week"}#{period_name total.period}"
    detail = "Income #{money(total.income, whole: true)} · Spent #{money(total.spent, whole: true)}"

    Readout.new(heading:, amount: money(total.net.abs), detail:, tone:)
  end

  Axis = Data.define(:ticks) do
    def top
      ticks.last
    end
  end

  def chart_axis(peak)
    step = axis_step(peak)
    count = [ (peak.to_f / step).ceil, 1 ].max

    Axis.new(ticks: (0..count).map { |index| index * step })
  end

  def axis_label(cents)
    dollars = cents / 100.0

    if dollars >= 1_000_000
      "$#{number_with_precision(dollars / 1_000_000, precision: 1, strip_insignificant_zeros: true)}M"
    elsif dollars >= 1_000
      "$#{number_with_precision(dollars / 1_000, precision: 1, strip_insignificant_zeros: true)}k"
    else
      "$#{number_with_precision(dollars, precision: 1, strip_insignificant_zeros: true)}"
    end
  end

  def axis_offset(cents, top)
    "#{(cents * 100.0 / top).round(2)}%"
  end

  def column_height(cents, top)
    [ (cents * PLOT_HEIGHT.to_f / top).round, 4 ].max
  end

  def category_color(index)
    if index.zero?
      "bg-data-strong"
    else
      "bg-data"
    end
  end

  def column_labels(period, columns)
    if columns.size <= MAX_LABELLED_COLUMNS
      columns.keys.map { |column| [ column_label(period, column), 1 ] }
    else
      columns.keys.each_slice(LABEL_SPAN).map { |week| [ column_label(period, week.first), week.size ] }
    end
  end

  def total_readout(total)
    "#{period_abbreviation(total.period)} · income #{money(total.income, whole: true)} · spent #{money(total.spent, whole: true)}"
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
    def axis_step(peak)
      rough = [ peak, 100 ].max / 100.0 / MAX_TICKS
      magnitude = 10**Math.log10(rough).floor
      step = ROUND_STEPS.map { |round| round * magnitude }.find { |candidate| candidate >= rough }

      ([ step, 1 ].max * 100).round
    end

    def column_label(period, column)
      if period.unit == :month
        column.strftime("%b")
      else
        short_date(column)
      end
    end
end
