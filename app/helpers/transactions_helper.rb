module TransactionsHelper
  CATEGORY_FIELD_SLOT = "flex min-w-24 max-w-[140px] flex-1"

  CATEGORY_FIELD = "flex h-7 w-full cursor-text items-center rounded-sm border border-primary bg-level-2 px-2.5 text-sm text-tertiary hover:border-(--ring-color-focus)"

  CATEGORY_LINK = "cursor-pointer text-secondary underline decoration-dotted underline-offset-3 hover:text-primary"

  ACTION_ICONS = {
    note: '<path d="M2.8 13.2l.5-2.8c2.5-2.6 5-5.1 7.7-7.6.5-.5 1.3-.5 1.8 0l.4.4c.5.5.5 1.3 0 1.8-2.5 2.6-5 5.1-7.6 7.7z"/><path d="M9.7 4.2c.9.7 1.6 1.4 2.2 2.3"/>',
    exclude: '<path d="M8.3 2.6c3 .1 5.2 2.5 5.1 5.5-.1 3-2.5 5.3-5.5 5.2-3-.1-5.3-2.6-5.2-5.5.1-2.8 2.3-5 5.1-5.3"/><path d="M4.4 11.7c2.3-2.6 4.8-5.1 7.3-7.5"/>',
    include: '<path d="M8.3 2.6c3 .1 5.2 2.5 5.1 5.5-.1 3-2.5 5.3-5.5 5.2-3-.1-5.3-2.6-5.2-5.5.1-2.8 2.3-5 5.1-5.3"/><path d="M5.5 8.3c.6.5 1.2 1.1 1.7 1.8 1-1.4 2.1-2.6 3.3-3.8"/>',
    delete: '<path d="M2.6 4.5c3.6-.4 7.3-.3 10.9.1"/><path d="M6.1 4.3c0-1.1.8-1.7 1.9-1.7 1.1 0 1.9.6 1.9 1.7"/>' \
      '<path d="M3.9 4.7c.2 2.7.4 5.3.7 7.9.1.6.5 1 1.1 1h4.6c.6 0 1-.4 1.1-1 .3-2.6.5-5.2.7-7.8"/><path d="M6.7 7.1c0 1.4 0 2.8.1 4.2M9.4 7.1c0 1.4 0 2.8-.1 4.2"/>'
  }.freeze

  ICON_BUTTON = "size-8 shrink-0 cursor-pointer items-center justify-center rounded-sm text-secondary hover:bg-level-3 hover:text-primary pointer-coarse:size-10"

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

  def excluded_tag(**options)
    tag.span "Excluded", class: [ "shrink-0 rounded-[4px] bg-level-3 px-1.5 py-px text-xs text-tertiary", options[:class] ]
  end

  def exclusion_button(transaction, icon: false, **options)
    label = transaction.excluded? ? "Include" : "Exclude"
    path = transaction_exclusion_path(transaction)
    params = { transaction: { excluded: !transaction.excluded? } }

    if icon
      icon_button_to label, label.downcase.to_sym, path, method: :patch, params:, **options
    else
      button_to label, path, method: :patch, params:, **options
    end
  end

  def icon_button_to(label, icon, url, **options)
    button_to url, aria: { label: }, title: label, class: [ "flex", ICON_BUTTON ], **options do
      action_icon(icon)
    end
  end

  def action_icon(name, size: 16, **options)
    tag.svg(
      ACTION_ICONS.fetch(name).html_safe,
      width: size,
      height: size,
      viewBox: "0 0 16 16",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.5,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      aria: { hidden: true },
      **options
    )
  end

  def transfer_icon(size: 14)
    tag.svg(
      tag.path(d: "M2 4.5h9M8.5 2l2.5 2.5L8.5 7M12 9.5H3M5.5 7L3 9.5 5.5 12", fill: "none", stroke: "currentColor",
        "stroke-width": 1.3, "stroke-linecap": "round", "stroke-linejoin": "round"),
      width: size, height: size, viewBox: "0 0 14 14", aria: { hidden: true }
    )
  end

  def pencil_icon
    action_icon :note, size: 12, class: "shrink-0 text-tertiary"
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

  def day_heading(date)
    date.strftime("%a, %b %-d")
  end

  def month_title(month)
    month.first_day.strftime("%B %Y")
  end

  def short_month_title(month)
    month.first_day.strftime("%b %Y")
  end

  def month_abbreviation(month)
    month.first_day.strftime("%b")
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
