module TrendsHelper
  SPARKLINE_HEIGHT = 28
  NOTE_COLORS = { good: "text-success", neutral: "text-primary" }

  def month_readout(month)
    "#{month_abbreviation month.month} · income #{money(month.income, whole: true)} · spent #{money(month.spent, whole: true)}#{" so far" if month.partial?}"
  end

  def note_color(note)
    NOTE_COLORS.fetch(note.tone)
  end
end
