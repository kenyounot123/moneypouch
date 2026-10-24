# What each of a user's categories holds: its transactions and rules, and what it added up to over a span of months.
class Category::Usage
  attr_reader :span

  def initialize(user, span)
    @user = user
    @span = span
  end

  # Every kept transaction and rule, whatever the span, since a merge or delete moves all of them.
  def transactions_count(category)
    transaction_counts.fetch(category.id, 0)
  end

  def rules_count(category)
    rule_counts.fetch(category.id, 0)
  end

  # Spent for a spending category and income for an income one, so a refund lowers what was spent.
  def total(category)
    signed(category, totals.fetch(category.id, 0))
  end

  # Whether the category's own page lists anything in the span, excluded transactions included.
  def active?(category)
    active_ids.include?(category.id)
  end

  def last_on(category)
    last_dates[category.id]
  end

  # Money that came back into a spending category over the span, already taken off its total.
  def refunded(category)
    if category.income?
      0
    else
      refunds.fetch(category.id, 0)
    end
  end

  # The category's total in each of the last 12 months, oldest first.
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
      @user.transactions.counted.categorized.occurred_in(span.range)
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
      @monthly_totals ||= @user.transactions.counted.categorized.occurred_in(span.year.range)
        .pluck(:category_id, :occurred_on, :amount_in_cents)
        .each_with_object(Hash.new(0)) { |(category_id, on, cents), totals| totals[[ category_id, on.beginning_of_month ]] += cents }
    end
end
