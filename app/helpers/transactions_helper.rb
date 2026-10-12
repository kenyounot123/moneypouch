module TransactionsHelper
  def money(amount_in_cents)
    amount = number_to_currency(amount_in_cents.abs.to_d / 100)

    if amount_in_cents.positive?
      "+#{amount}"
    else
      amount
    end
  end

  def categorization_label(transaction)
    if transaction.transfer?
      "Transfer"
    else
      transaction.category&.name || "Uncategorized"
    end
  end

  def transfer_icon(size: 14)
    tag.svg(
      tag.path(d: "M2 4.5h9M8.5 2l2.5 2.5L8.5 7M12 9.5H3M5.5 7L3 9.5 5.5 12", fill: "none", stroke: "currentColor",
        "stroke-width": 1.3, "stroke-linecap": "round", "stroke-linejoin": "round"),
      width: size, height: size, viewBox: "0 0 14 14", aria: { hidden: true }
    )
  end

  def categorization_chip(categorization)
    if categorization.transfer?
      tag.span safe_join([ transfer_icon(size: 12), "Transfer" ]),
        class: "inline-flex shrink-0 items-center gap-1.25 rounded-[4px] border border-secondary px-1.75 py-px align-middle text-sm font-medium text-tertiary"
    else
      tag.span categorization.category.name,
        class: "inline-block max-w-full truncate rounded-[4px] border border-secondary bg-level-3 px-1.75 py-px align-middle text-sm font-medium text-primary"
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

  def shortcut(key)
    if request.user_agent.to_s.include?("Macintosh")
      "⌘#{key}"
    else
      "Ctrl #{key}"
    end
  end
end
