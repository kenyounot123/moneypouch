module TrendsHelper
  NOTE_COLORS = { good: "text-success", neutral: "text-primary" }
  HEAT_CLASSES = %w[ bg-data-track bg-data/40 bg-data/60 bg-data/80 bg-data ]

  def month_readout(month)
    "#{month_abbreviation month.month}#{" (present)" if month.partial?} · income #{money(month.income, whole: true)} · spent #{money(month.spent, whole: true)}"
  end

  def charge_detail(charge)
    [ "Usually on the #{charge.day.ordinalize}",
      ("was #{money charge.previous_amount}" if charge.previous_amount) ].compact.join(" · ")
  end

  def income_rhythm(source)
    "Usually arrives on the #{source.days.map(&:ordinalize).to_sentence}" if source.days.any?
  end

  def heat_class(cents, peak)
    if cents.positive?
      HEAT_CLASSES[(cents * 4.0 / peak).ceil.clamp(1, 4)]
    else
      HEAT_CLASSES.first
    end
  end

  def note_color(note)
    NOTE_COLORS.fetch(note.tone)
  end
end
