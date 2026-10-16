class Import::Row < Data.define(:tab, :number, :occurred_on, :name, :amount_in_cents, :category_word, :transfer, :excluded, :note, :key)
  KEY_PREFIX = "import:"
  private_constant :KEY_PREFIX

  def self.key(occurred_on, unsigned_cents, normalized_name, ordinal)
    KEY_PREFIX + Digest::SHA256.hexdigest([ occurred_on.iso8601, unsigned_cents, normalized_name, ordinal ].join("\u001F"))
  end

  def self.identity(occurred_on:, amount_in_cents:, name:)
    [ occurred_on, amount_in_cents, name.downcase.squish ]
  end

  def identity
    self.class.identity(occurred_on:, amount_in_cents:, name:)
  end

  def transfer?
    transfer
  end

  def excluded?
    excluded
  end

  def counted?
    !transfer? && !excluded?
  end
end
