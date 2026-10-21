class Import::CategoryWord < Data.define(:word, :count, :match, :name, :income, :money_in_name)
  # Stands in for rows with no word, and for transfers, which never carry one.
  def self.uncategorized(money_in_name:)
    new(word: nil, count: 0, match: nil, name: "", income: false, money_in_name:)
  end

  def matched?
    match.present? && name.casecmp?(match.name)
  end

  def categorized?
    name.present?
  end

  def income?
    income
  end

  def category_name_for(row)
    if row.transfer?
      ""
    elsif row.money_in? && money_in_name
      money_in_name
    else
      name
    end
  end
end
