class Import::Row < Data.define(:tab, :number, :occurred_on, :name, :amount_in_cents, :category_word, :excluded, :note, :key)
  KEY_PREFIX = "import:"
  private_constant :KEY_PREFIX

  def self.key(occurred_on, unsigned_cents, normalized_name, ordinal)
    KEY_PREFIX + Digest::SHA256.hexdigest([ occurred_on.iso8601, unsigned_cents, normalized_name, ordinal ].join("\u001F"))
  end

  def excluded?
    excluded
  end
end
