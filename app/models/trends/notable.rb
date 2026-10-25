module Trends::Notable
  extend ActiveSupport::Concern

  NOTES_LIMIT = 4
  BELOW_USUAL_CENTS = 2_000
  BELOW_USUAL_SHARE = 0.1
  LOWEST_SINCE_MONTHS = 4
  POSITIVE_NET_RECENT = 6
  POSITIVE_NET_MINIMUM = 3

  def notes
    @notes ||= [ lowest_since_note, below_usual_note, positive_net_months_note, charge_stopped_note, new_income_note ]
      .compact.uniq { |note| [ note.category || note.kind, note.month ] }.first(NOTES_LIMIT)
  end

  def lowest_since_note
    month, *earlier = periods[0...-1].reverse
    runs = spending_lines.filter_map do |line|
      lowest = line.series.fetch(month)
      next unless line.category && lowest.positive?

      higher = earlier.take_while { |period| line.series.fetch(period) > lowest }
      ended = earlier[higher.size] if earlier[higher.size] && line.series.fetch(earlier[higher.size]).positive?
      [ line, higher.size, ended ] if higher.size >= LOWEST_SINCE_MONTHS
    end

    line, run, ended = runs.max_by { |line, run, _| [ run, line.total ] }
    if line
      Trends::Note.new(kind: :lowest_since, tone: :good, text: "#{month.first_day.strftime("%B")} was your lowest #{line.label} month #{ended ? "since #{ended.first_day.strftime("%B")}" : "in #{run + 1} months"}.",
        category: line.category, month:)
    end
  end

  def below_usual_note
    below = spending_lines.filter_map do |line|
      next unless line.category && line.usual

      gap = line.usual - line.series.fetch(last_full)
      [ line, gap ] if gap >= BELOW_USUAL_CENTS && gap >= line.usual * BELOW_USUAL_SHARE
    end

    line, = below.max_by(&:last)
    if line
      Trends::Note.new(kind: :below_usual, tone: :good, text: "You spent less than usual on #{line.label} in #{last_full.first_day.strftime("%B")}.",
        category: line.category, month: last_full)
    end
  end

  def positive_net_months_note
    positive = months[0...-1].last(POSITIVE_NET_RECENT).count(&:positive_net)

    if positive >= POSITIVE_NET_MINIMUM
      Trends::Note.new(kind: :positive_net_months, tone: :good, text: "Your net was positive in #{positive} of the last #{POSITIVE_NET_RECENT} months.")
    end
  end

  def charge_stopped_note
    charge = stopped.find { |stopped| periods[-3].range.cover?(stopped.last_on) && today.day > stopped.day }

    if charge
      Trends::Note.new(kind: :charge_stopped, tone: :neutral, text: "Your #{charge.name} charge stopped.")
    end
  end

  def new_income_note
    recent = sources.find { |source| source.first_on >= last_full.first_day }

    if recent
      Trends::Note.new(kind: :new_income, tone: :good, text: "New income from #{recent.name}.")
    end
  end
end
