class Category::Span
  LENGTHS = [ 1, 3, 12 ]
  DEFAULT_LENGTH = 3

  attr_reader :months

  def self.from(params, today:)
    if params[:month].present?
      new(last: Period.month(params[:month], today:), length: 1)
    else
      new(last: Period.new("month", today:), length: params[:months].to_i.presence_in(LENGTHS) || DEFAULT_LENGTH)
    end
  end

  def initialize(last:, length:)
    @months = (1...length).each_with_object([ last ]) { |_, months| months.unshift(months.first.previous) }
  end

  def last
    months.last
  end

  def length
    months.size
  end

  def range
    months.first.first_day..last.range.end
  end

  def current?
    last.current?
  end

  def one_month?
    length == 1
  end

  def cover?(month)
    months.include?(month)
  end

  def year
    Category::Span.new(last: Period.new("month", today: last.today), length: 12)
  end

  def ==(other)
    other.is_a?(Category::Span) && months == other.months
  end
  alias_method :eql?, :==

  def hash
    months.hash
  end
end
