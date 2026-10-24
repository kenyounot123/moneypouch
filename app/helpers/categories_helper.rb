module CategoriesHelper
  def category_holdings(category, usage)
    holdings(category, usage).join(" · ")
  end

  def merge_category_question(category, usage)
    "Merge #{category.name} into the category you picked? Its #{holdings(category, usage).to_sentence} move there, and #{category.name} goes away."
  end

  def delete_category_question(category, usage)
    transactions = usage.transactions_count(category)
    rules = usage.rules_count(category)

    [ "Delete #{category.name}?",
      ("Its #{pluralize(number_with_delimiter(transactions), "transaction")} become uncategorized." if transactions.positive?),
      ("Its #{pluralize(rules, "rule")} will be forgotten." if rules.positive?) ].compact.join(" ")
  end

  private
    def holdings(category, usage)
      rules = usage.rules_count(category)

      [ pluralize(number_with_delimiter(usage.transactions_count(category)), "transaction"),
        (pluralize(rules, "rule") if rules.positive?) ].compact
    end
end
