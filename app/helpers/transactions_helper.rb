module TransactionsHelper
  CATEGORY_FIELD_SLOT = "flex min-w-24 max-w-[140px] flex-1"

  CATEGORY_FIELD = "flex h-7 w-full cursor-text items-center rounded-sm border border-primary bg-level-2 px-2.5 text-sm text-tertiary hover:border-(--ring-color-focus)"

  CATEGORY_LINK = "cursor-pointer text-secondary underline decoration-dotted underline-offset-3 hover:text-primary"

  ICON_BUTTON = "size-8 shrink-0 cursor-pointer items-center justify-center rounded-sm text-secondary hover:bg-level-3 hover:text-primary pointer-coarse:size-10"

  EXCLUSION_BUTTON = "flex h-8 min-w-8 shrink-0 cursor-pointer items-center justify-center gap-1.5 rounded-sm text-sm text-secondary hover:bg-level-3 hover:text-primary pointer-coarse:h-10 pointer-coarse:min-w-10 @3xl:px-2"

  def money(amount_in_cents)
    amount = number_to_currency(amount_in_cents.abs.to_d / 100)

    if amount_in_cents.positive?
      "+#{amount}"
    else
      amount
    end
  end

  def money_color(amount_in_cents, otherwise: nil)
    if amount_in_cents.positive?
      "text-success"
    else
      otherwise
    end
  end

  def amount_color(transaction)
    if transaction.counted?
      money_color(transaction.amount_in_cents)
    else
      "text-tertiary"
    end
  end

  def categorization_label(transaction)
    if transaction.transfer?
      "Transfer"
    else
      transaction.category&.name || "Uncategorized"
    end
  end

  def picker_categories(categories)
    categories.map { |category| [ category.name, category.income? ] }.to_json
  end

  def excluded_tag(**options)
    tag.span "Excluded", class: [ "shrink-0 rounded-[4px] bg-level-3 px-1.5 py-px text-xs text-tertiary", options[:class] ]
  end

  def exclusion_button(transaction, icon: false, **options)
    path = transaction_exclusion_path(transaction)
    params = { transaction: { excluded: !transaction.excluded? } }

    if transaction.excluded?
      label = "Include in totals"
      icon_name = :include
    else
      label = "Exclude from totals"
      icon_name = :exclude
    end

    if icon
      button_to path, method: :patch, params:, aria: { label: }, title: label, class: EXCLUSION_BUTTON, **options do
        safe_join([ icon_tag(icon_name), tag.span(label, class: "hidden @3xl:inline") ])
      end
    else
      button_to label, path, method: :patch, params:, **options
    end
  end

  def icon_button_to(label, icon, url, **options)
    button_to url, aria: { label: }, title: label, class: [ "flex", ICON_BUTTON ], **options do
      icon_tag(icon)
    end
  end

  def categorization_chip(categorization)
    if categorization.transfer?
      tag.span safe_join([ icon_tag("transfer", class: "size-3"), "Transfer" ]),
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
