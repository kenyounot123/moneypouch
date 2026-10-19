class Import::CategoryWord < Data.define(:word, :count, :match, :name, :income)
  def matched?
    match.present? && name.casecmp?(match.name)
  end

  def categorized?
    name.present?
  end

  def income?
    income
  end
end
