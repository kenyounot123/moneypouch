class Import::Tally < Data.define(:spent, :refunds, :income, :transfers, :excluded, :unreadable, :already_here)
  def adding
    spent + refunds + income + transfers + excluded
  end
end
