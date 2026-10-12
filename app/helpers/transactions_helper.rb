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

  def pencil_icon
    tag.svg(
      tag.path(d: "M7.5 2l2.5 2.5L4.5 10H2V7.5z", fill: "none", stroke: "currentColor", "stroke-width": 1.2, "stroke-linejoin": "round"),
      width: 12, height: 12, viewBox: "0 0 12 12", class: "shrink-0 text-tertiary", aria: { hidden: true }
    )
  end

  def categorization_chip(categorization)
    if categorization.transfer?
      tag.span safe_join([ transfer_icon(size: 12), "Transfer" ]),
        class: "inline-flex shrink-0 items-center gap-1.25 rounded-[4px] border border-secondary px-1.75 py-px text-sm font-medium text-tertiary"
    else
      tag.span categorization.category.name,
        class: "inline-block rounded-[4px] border border-secondary bg-level-3 px-1.75 py-px text-sm font-medium text-primary"
    end
  end

  def offering_rule?(transaction)
    flash[:categorized_id] == transaction.id && transaction.offers_rule?
  end

  def rule_reach(transaction)
    waiting = transaction.waiting_namesake_count

    if waiting.zero?
      "Applies to future syncs."
    else
      "#{waiting} more waiting now, plus future syncs."
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
