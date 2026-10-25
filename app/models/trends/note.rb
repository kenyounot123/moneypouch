class Trends::Note < Data.define(:kind, :tone, :text, :category, :month)
  TONES = %i[ good neutral ]

  def initialize(kind:, tone:, text:, category: nil, month: nil)
    raise ArgumentError, "a note's tone is one of #{TONES.inspect}, not #{tone.inspect}" unless TONES.include?(tone)

    super
  end
end
