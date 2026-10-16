class Import::Tally < Data.define(:spent, :income, :excluded, :unreadable, :already_here)
  def adding
    spent + income + excluded
  end
end
