class Category::Usage
  attr_reader :span

  def initialize(user, span)
    @user = user
    @span = span
  end

  def transactions_count(category)
    transaction_counts.fetch(category.id, 0)
  end

  def rules_count(category)
    rule_counts.fetch(category.id, 0)
  end

  def total(category)
    signed(category, totals.fetch(category.id, 0))
  end

  def section_total(categories)
    categories.reject(&:excluded?).sum { |category| total(category) }
  end

  def counts_in_section?(categories)
    categories.any? { |category| active?(category) && !category.excluded? }
  end

  def active?(category)
    active_ids.include?(category.id)
  end

  def last_on(category)
    last_dates[category.id]
  end

  def refunded(category)
    if category.income?
      0
    else
      refunds.fetch(category.id, 0)
    end
  end

  def months(category)
    span.year.months.index_with { |month| signed(category, monthly_totals.fetch([ category.id, month.first_day ], 0)) }
  end

  def monthly_average(category)
    months(category).values.sum / span.year.length
  end

  private
    def signed(category, cents)
      if category.income?
        cents
      else
        -cents
      end
    end

    def transaction_counts
      @transaction_counts ||= @user.transactions.categorized.group(:category_id).count
    end

    def rule_counts
      @rule_counts ||= @user.rules.where.not(category_id: nil).group(:category_id).count
    end

    def counted_in_span
      @user.transactions.individually_counted.categorized.occurred_in(span.range)
    end

    def totals
      @totals ||= counted_in_span.group(:category_id).sum(:amount_in_cents)
    end

    def refunds
      @refunds ||= counted_in_span.money_in.group(:category_id).sum(:amount_in_cents)
    end

    def active_ids
      @active_ids ||= @user.transactions.categorized.occurred_in(span.range).distinct.pluck(:category_id).to_set
    end

    def last_dates
      @last_dates ||= @user.transactions.categorized.group(:category_id).maximum(:occurred_on)
    end

    def monthly_totals
      @monthly_totals ||= @user.transactions.individually_counted.categorized.occurred_in(span.year.range)
        .pluck(:category_id, :occurred_on, :amount_in_cents)
        .each_with_object(Hash.new(0)) { |(category_id, on, cents), totals| totals[[ category_id, on.beginning_of_month ]] += cents }
    end
end
