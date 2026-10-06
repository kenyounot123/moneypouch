class Period
  KINDS = %w[ week month year ]

  attr_reader :kind, :today

  def initialize(kind, today:)
    @kind = kind.presence_in(KINDS) || "month"
    @today = today
  end

  def range
    case kind
    when "week" then today.all_week
    when "month" then today.all_month
    when "year" then today.all_year
    end
  end

  def elapsed
    range.begin..today
  end

  def previous
    Period.new(kind, today: today.advance("#{kind}s": -1))
  end

  def unit
    if kind == "year"
      :month
    else
      :day
    end
  end

  def columns
    if unit == :month
      range.select { |date| date.day == 1 }
    else
      range.to_a
    end
  end

  def column_for(date)
    if unit == :month
      date.beginning_of_month
    else
      date
    end
  end

  def column_range(column)
    if unit == :month
      column.all_month
    else
      column..column
    end
  end

  def day
    (today - range.begin).to_i + 1
  end

  def days
    range.count
  end
end
