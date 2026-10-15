class Import::Row < Data.define(:tab, :number, :occurred_on, :name, :amount_in_cents, :category_word, :excluded, :note, :key)
  KEY_PREFIX = "import:"

  # From content only, so a newer copy of the file gives the rows it shares with the old one the same keys.
  # The ordinal counts identical rows in the file, so two $5 coffees on one day stay two. The amount is
  # unsigned so flipping which way positive amounts go between uploads adds no duplicates.
  def self.key(occurred_on, unsigned_cents, normalized_name, ordinal)
    KEY_PREFIX + Digest::SHA256.hexdigest([ occurred_on.iso8601, unsigned_cents, normalized_name, ordinal ].join("\u001F"))
  end

  def excluded?
    excluded
  end
end
