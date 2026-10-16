class Import::CategoryWord < Data.define(:word, :count, :match, :name)
  def matched?
    match.present? && name.casecmp?(match.name)
  end
end
