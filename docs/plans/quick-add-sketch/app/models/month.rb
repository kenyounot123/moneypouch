# P5 (lands with the time zone work so P6 and P7, built in parallel, share it).
# A calendar month. The one place that knows month boundaries, `?month=` parsing,
# and "how far into this month are we".
#
#   Month.current                 # in the request's zone (Time.use_zone)
#   Month.parse(params[:month])   # "2026-08" -> Aug 2026; nil/"garbage"/"2026-13" -> current
#   month.dates                   # Date range, first..last
#   month.previous / month.next
#   month.to_param                # "2026-08", for month links
Month = Data.define(:first) do
  def self.current
    new(first: Date.current.beginning_of_month)
  end

  # @return [Month] never raises; anything unreadable is the current month
  def self.parse(param)
    raise NotImplementedError # /\A(\d{4})-(\d{2})\z/ + Date.valid_date? else current
  end

  def last = first.end_of_month

  def dates = first..last

  def previous = Month.new(first: first.prev_month)

  def next = Month.new(first: first.next_month)

  def current? = first == Date.current.beginning_of_month

  def days_in_month = last.day

  # Days elapsed including today for the current month; all days for a past one.
  def elapsed_days
    raise NotImplementedError
  end

  def to_param = first.strftime("%Y-%m")

  def name = first.strftime("%B")
end
