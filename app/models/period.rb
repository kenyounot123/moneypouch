class Period
  KINDS = %w[ week month year ]

  attr_reader :kind, :today

  # Reads the year and month the Transactions page puts in its URL, like 2026-10.
  def self.month(param, today:)
    new("month", today:, on: Date.strptime(param.to_s, "%Y-%m"))
  rescue Date::Error
    new("month", today:)
  end

  def initialize(kind, today:, on: nil)
    @kind = kind.presence_in(KINDS) || "month"
    @today = today
    @date = [ parse(on) || today, today ].min
  end

  def range
    case kind
    when "week" then @date.all_week
    when "month" then @date.all_month
    when "year" then @date.all_year
    end
  end

  def first_day
    range.begin
  end

  def previous
    Period.new(kind, today:, on: first_day - 1)
  end

  def next
    unless current?
      Period.new(kind, today:, on: range.end + 1)
    end
  end

  def current?
    range.cover?(today)
  end

  def ==(other)
    other.is_a?(Period) && kind == other.kind && range == other.range
  end
  alias_method :eql?, :==

  def hash
    [ kind, range ].hash
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

  def day
    (today - range.begin).to_i + 1
  end

  def days
    range.count
  end

  private
    def parse(on)
      if on.is_a?(Date)
        on
      else
        Date.iso8601(on.to_s)
      end
    rescue Date::Error
      nil
    end
end
