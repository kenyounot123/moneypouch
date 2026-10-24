# What each of a user's categories holds: its transactions, its rules, and its total for one period.
class Category::Usage
  attr_reader :period

  def initialize(user, period)
    @user = user
    @period = period
  end

  def transactions_count(category)
    transaction_counts.fetch(category.id, 0)
  end

  def rules_count(category)
    rule_counts.fetch(category.id, 0)
  end

  # Spent for a spending category and received for an income one, so a refund lowers what was spent.
  def total(category)
    cents = totals.fetch(category.id, 0)

    if category.income?
      cents
    else
      -cents
    end
  end

  private
    def transaction_counts
      @transaction_counts ||= @user.transactions.categorized.group(:category_id).count
    end

    def rule_counts
      @rule_counts ||= @user.rules.where.not(category_id: nil).group(:category_id).count
    end

    def totals
      @totals ||= @user.transactions.counted.categorized.occurred_in(period.range).group(:category_id).sum(:amount_in_cents)
    end
end
