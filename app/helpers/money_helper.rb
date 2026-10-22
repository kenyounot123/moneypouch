module MoneyHelper
  MINUS = "−"

  # $5.50, and −$5.50 below zero.
  def money(cents, whole: false)
    if cents.negative?
      "#{MINUS}#{dollars(-cents, whole:)}"
    else
      dollars(cents, whole:)
    end
  end

  # +$5.50 above zero, −$5.50 below, $0.00 at zero.
  def signed_money(cents, whole: false)
    if cents.positive?
      "+#{money(cents, whole:)}"
    else
      money(cents, whole:)
    end
  end

  # Money out plain and money in with a plus, as a row or a day total reads.
  def money_flow(cents)
    if cents.positive?
      signed_money(cents)
    else
      money(-cents)
    end
  end

  def money_color(amount_in_cents, otherwise: nil)
    if amount_in_cents.positive?
      "text-success"
    else
      otherwise
    end
  end

  private
    def dollars(cents, whole:)
      if whole
        number_to_currency((cents.to_d / 100).round, precision: 0)
      else
        number_to_currency(cents.to_d / 100)
      end
    end
end
