# The things worth saying about the last few months. Each detector reads a Trends and returns a Trends::Note or nil.
module Trends::Notes
  LIMIT = 4

  module BelowUsual
    MINIMUM_CENTS = 2_000
    MINIMUM_SHARE = 0.1

    def self.call(trends)
      month = trends.last_full
      below = trends.spending_lines.filter_map do |line|
        next unless line.category && line.usual

        gap = line.usual - line.series.fetch(month)
        [ line, gap ] if gap >= MINIMUM_CENTS && gap >= line.usual * MINIMUM_SHARE
      end

      line, = below.max_by(&:last)
      if line
        Trends::Note.new(kind: :below_usual, tone: :good, text: "#{line.label} came in under your usual in #{month.first_day.strftime("%B")}.",
          path: Trends::Notes.category_path(line.category, month))
      end
    end
  end

  module LowestSince
    MINIMUM_HISTORY = 4

    def self.call(trends)
      month, *earlier = trends.periods[0...-1].reverse
      runs = trends.spending_lines.filter_map do |line|
        lowest = line.series.fetch(month)
        next unless line.category && lowest.positive?

        higher = earlier.take_while { |period| line.series.fetch(period) > lowest }
        [ line, higher.size, earlier[higher.size] ] if higher.size >= MINIMUM_HISTORY
      end

      line, run, ended = runs.max_by { |line, run, _| [ run, line.total ] }
      if line
        Trends::Note.new(kind: :lowest_since, tone: :good, text: "Your lowest #{line.label} month #{ended ? "since #{ended.first_day.strftime("%B")}" : "in the last #{run + 1} months"}.",
          path: Trends::Notes.category_path(line.category, month))
      end
    end
  end

  module KeptMonths
    RECENT = 6
    MINIMUM = 3

    def self.call(trends)
      kept = trends.months[0...-1].last(RECENT).count(&:kept)

      if kept >= MINIMUM
        Trends::Note.new(kind: :kept_months, tone: :good, text: "You kept money in #{kept} of the last #{RECENT} months.")
      end
    end
  end

  DETECTORS = [ BelowUsual, LowestSince, KeptMonths ]

  def self.for(trends, detectors: DETECTORS)
    detectors.filter_map { |detector| detector.call(trends) }.first(LIMIT)
  end

  def self.category_path(category, period)
    Rails.application.routes.url_helpers.category_path(category, month: period.first_day.strftime("%Y-%m"))
  end
end
