# P5. Signed cents to display text. One formatter for pills, rows, totals.
module MoneyHelper
  # money(-550) => "$5.50"   money(200000) => "+$2,000.00"   money(-550, sign: false) => "$5.50"
  def money(cents, sign: true)
    raise NotImplementedError
  end

  # short_date(Date.new(2026, 9, 26)) => "Sep 26"
  def short_date(date) = date.strftime("%b %-d")

  # relative_day(Date.current) => "today"; yesterday => "yesterday"; else "Fri, Oct 2"
  def relative_day(date)
    raise NotImplementedError
  end
end
