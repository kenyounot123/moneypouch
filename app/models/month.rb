class Month
  attr_reader :first_day, :today

  def initialize(param, today:)
    @today = today
    @first_day = [ parse(param) || today.beginning_of_month, today.beginning_of_month ].min
  end

  def range
    first_day.all_month
  end

  def previous
    Month.new(first_day.prev_month.strftime("%Y-%m"), today:)
  end

  def next
    unless current?
      Month.new(first_day.next_month.strftime("%Y-%m"), today:)
    end
  end

  def current?
    first_day == today.beginning_of_month
  end

  def to_param
    first_day.strftime("%Y-%m")
  end

  def name
    first_day.strftime("%B")
  end

  private
    def parse(param)
      Date.strptime(param.to_s, "%Y-%m")
    rescue Date::Error
      nil
    end
end
