class BankTransaction::Name < Data.define(:payee, :description)
  ZELLE = /\AZelle (?:Transfer|payment) (?:to|from) /i
  REFERENCE = /\s+\S*\d\S*\z/

  def to_s
    from_payee = clean(payee.to_s)

    if from_payee.blank? || from_payee.match?(/\AZelle\b/i)
      clean(description)
    else
      from_payee
    end
  end

  def key
    to_s.downcase.gsub(/[^a-z\s]/, "").squish
  end

  private
    def clean(text)
      name = text.squish.sub(ZELLE, "")

      while name.match?(REFERENCE)
        name = name.sub(REFERENCE, "")
      end

      name
    end
end
