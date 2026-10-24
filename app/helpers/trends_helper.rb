module TrendsHelper
  SPARKLINE_HEIGHT = 28
  NOTE_COLORS = { good: "text-success", neutral: "text-primary" }

  def month_readout(month)
    "#{month_abbreviation month.month} · income #{money(month.income, whole: true)} · spent #{money(month.spent, whole: true)}#{" so far" if month.partial?}"
  end

  def charge_detail(charge)
    [ "Usually on the #{charge.day.ordinalize}",
      ("now #{money charge.amount}, was #{money charge.previous_amount}" if charge.previous_amount) ].compact.join(" · ")
  end

  def note_color(note)
    NOTE_COLORS.fetch(note.tone)
  end
end
