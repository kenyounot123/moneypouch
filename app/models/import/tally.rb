# What the preview shows: the new rows by kind, the rows already here, what can't be read, and the total to check against the file.
class Import::Tally < Data.define(:lines, :already_here, :unreadable_rows, :stated_totals, :rows)
  KINDS = %i[ spent refund income transfer excluded ]
  Line = Data.define(:kind, :count, :cents)

  def adding
    lines.sum(&:count)
  end

  def new_cents
    lines.sum(&:cents)
  end

  def already_here_cents
    already_here.keys.sum(&:written_cents)
  end

  def total_cents
    rows.sum(&:written_cents)
  end

  # nil with no Total row in the file, :matches when every one adds up, else the first that doesn't.
  def total_check
    if stated_totals.any?
      sums = rows.group_by(&:tab).transform_values { |tab_rows| tab_rows.sum(&:written_cents) }
      stated_totals.find { |stated| sums.fetch(stated.tab, 0) != stated.cents } || :matches
    end
  end
end
