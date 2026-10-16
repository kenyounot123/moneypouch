class Import::Tally < Data.define(:spent, :income, :transfers, :excluded, :unreadable, :already_here)
  def adding
    spent + income + transfers + excluded
  end
end
