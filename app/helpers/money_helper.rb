module MoneyHelper
  MINUS = "−"

  def money(cents, whole: false)
    if cents.negative?
      "#{MINUS}#{dollars(-cents, whole:)}"
    else
      dollars(cents, whole:)
    end
  end

  def signed_money(cents, whole: false)
    if cents.positive?
      "+#{money(cents, whole:)}"
    else
      money(cents, whole:)
    end
  end

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
