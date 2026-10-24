module TrendsHelper
  def month_readout(month)
    "#{month_abbreviation month.month} · income #{money(month.income, whole: true)} · spent #{money(month.spent, whole: true)}#{" so far" if month.partial?}"
  end
end
