# One plain sentence for the Trends page. Only good or neutral news gets a note.
class Trends::Note < Data.define(:kind, :tone, :text, :path)
  TONES = %i[ good neutral ]

  def initialize(kind:, tone:, text:, path: nil)
    raise ArgumentError, "a note's tone is one of #{TONES.inspect}, not #{tone.inspect}" unless TONES.include?(tone)

    super
  end
end
