module TransactionsHelper
  def money(amount_in_cents)
    amount = number_to_currency(amount_in_cents.abs.to_d / 100)

    if amount_in_cents.positive?
      "+#{amount}"
    else
      amount
    end
  end

  def short_date(date)
    if date.year == Date.current.year
      date.strftime("%b %-d")
    else
      date.strftime("%b %-d, %Y")
    end
  end

  def relative_date(date)
    case date
    when Date.current then "Today"
    when Date.yesterday then "Yesterday"
    else short_date(date)
    end
  end
end
