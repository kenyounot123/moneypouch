class Rule::Book
  def initialize(user)
    @user = user
    @rules = user.rules.to_a
  end

  def categorized?(name)
    rule_for(name)&.category.present?
  end

  def categorization_for(name, paired: false)
    rule = rule_for(name)

    if rule
      rule.categorization
    elsif paired
      Transaction::Categorization.transfer
    else
      Transaction::Categorization.new(category: @user.transactions.last_category_for(name.to_s))
    end
  end

  private
    def rule_for(name)
      @rules.find { |rule| rule.matches?(name) }
    end
end
