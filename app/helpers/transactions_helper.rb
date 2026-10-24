module TransactionsHelper
  def amount_color(transaction)
    if transaction.counted?
      money_color(transaction.amount_in_cents)
    else
      "text-tertiary"
    end
  end

  def categorization_label(transaction)
    if transaction.transfer? && transaction.paired?
      "Transfer #{transaction.money_in? ? "from" : "to"} #{transaction.paired_account_name}"
    else
      category_field_value(transaction) || "Uncategorized"
    end
  end

  # What the category picker opens with, so a paired transfer's longer label is never read back as a new category.
  def category_field_value(transaction)
    if transaction.transfer?
      "Transfer"
    else
      transaction.category&.name
    end
  end

  def picker_categories(categories)
    categories.map { |category| [ category.name, category.income? ] }.to_json
  end

  def row_marker(label)
    tag.div class: "size-1.5 rounded-[1px] bg-highlight", role: "img", aria: { label: }
  end

  def excluded_tag(**options)
    tag.span "Excluded", class: [ "shrink-0 rounded-[4px] bg-level-3 px-1.5 py-px text-xs text-tertiary", options[:class] ]
  end

  def exclusion_button(transaction, icon: false, **options)
    label = transaction.excluded? ? "Include" : "Exclude"
    path = transaction_exclusion_path(transaction)
    method = transaction.excluded? ? :delete : :post

    if icon
      icon_button_to label, label.downcase.to_sym, path, method:, **options
    else
      button_to label, path, method:, **options
    end
  end

  def icon_button_to(label, icon, url, **options)
    button_to url, aria: { label: }, title: label, class: "flex icon-button", **options do
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

  def month_name(month)
    month.first_day.strftime("%B")
  end

  def month_param(month)
    month.first_day.strftime("%Y-%m")
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
