module VouchersHelper
  def voucher_marks(voucher)
    voucher.tokens.map do |token|
      kind = token.kind == :amount && voucher.money_in? ? :money_in : token.kind
      [ kind, utf16_length(voucher.shorthand[0, token.start]), utf16_length(voucher.shorthand[0, token.finish]) ]
    end
  end

  def voucher_calendar(voucher)
    if voucher.calendar
      { fragment: voucher.calendar, aim: voucher.aim&.to_h }.to_json
    end
  end

  def voucher_name_value(voucher)
    if voucher.name.present?
      tag.span voucher.name, class: "truncate font-medium"
    else
      tag.span "Required", class: "text-tertiary"
    end
  end

  def voucher_amount_value(voucher)
    if voucher.amount_in_cents
      tag.span money_flow(voucher.amount_in_cents), class: [ "truncate font-amount font-medium", voucher.money_in? ? "text-success" : "text-amount" ]
    else
      tag.span "Required", class: "text-tertiary"
    end
  end

  def voucher_date_value(voucher)
    tag.span relative_date(voucher.occurred_on), class: [ "truncate", ("text-date" if voucher.dated?) ]
  end

  def voucher_category_value(voucher)
    if voucher.category_name
      tag.span voucher.category_name, class: "truncate text-category"
    else
      tag.span "None yet", class: "text-tertiary"
    end
  end

  private
    def utf16_length(text)
      text.encode("UTF-16LE").bytesize / 2
    end
end
