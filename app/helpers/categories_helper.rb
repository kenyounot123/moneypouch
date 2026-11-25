module CategoriesHelper
  SPARK_HEIGHT = 20
  MONTH_BAR_HEIGHT = 120

  def category_kind(category)
    if category.income?
      "Income"
    else
      "Spent"
    end
  end

  def span_choices(today)
    Category::Span::LENGTHS.map { |length| Category::Span.new(last: Period.new("month", today:), length:) }
  end

  def span_label(span)
    if !span.one_month?
      "Last #{span.length} months"
    elsif span.current?
      month_name span.last
    else
      month_title span.last
    end
  end

  def span_phrase(span)
    if !span.one_month?
      "in the last #{span.length} months"
    elsif span.last.first_day.year == span.last.today.year
      "in #{month_name span.last}"
    else
      "in #{month_title span.last}"
    end
  end

  def span_params(span)
    if span.one_month? && !span.current?
      { month: month_param(span.last) }
    else
      { months: span.length }
    end
  end

  def month_bar_height(cents, peak, tallest = MONTH_BAR_HEIGHT)
    if cents.positive?
      [ (cents * tallest.to_f / peak).round, 2 ].max
    else
      0
    end
  end

  def month_bar_color(span, month, cents)
    if !cents.positive?
      "bg-data-track"
    elsif span.cover?(month)
      "bg-data-strong"
    else
      "bg-data-soft"
    end
  end

  def merge_category_question(category, usage, others)
    [ "Merge #{category.name} into the category you picked? Its #{holdings(category, usage).to_sentence} move there, and #{category.name} goes away.",
      ("They count in your totals again unless that category is excluded too." if category.excluded?),
      ("They leave your totals if that category is excluded." if !category.excluded? && others.any?(&:excluded?)) ].compact.join(" ")
  end

  def merge_target_options(others)
    options_for_select(others.map { |other| [ other.excluded? ? "#{other.name} (excluded)" : other.name, other.id ] })
  end

  def delete_category_question(category, usage)
    transactions = usage.transactions_count(category)
    rules = usage.rules_count(category)

    [ "Delete #{category.name}?",
      ("Its #{pluralize(number_with_delimiter(transactions), "transaction")} become uncategorized#{" and count in your totals again" if category.excluded?}." if transactions.positive?),
      ("Its #{pluralize(rules, "rule")} will be forgotten." if rules.positive?) ].compact.join(" ")
  end

  private
    def holdings(category, usage)
      rules = usage.rules_count(category)

      [ pluralize(number_with_delimiter(usage.transactions_count(category)), "transaction"),
        (pluralize(rules, "rule") if rules.positive?) ].compact
    end
end
