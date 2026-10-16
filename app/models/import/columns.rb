class Import::Columns < Data.define(:kinds, :positive_amounts)
  KINDS = %w[ skip date name amount spent_or_income category transfer excluded note ]
  POSITIVE_AMOUNTS = %w[ spent income ]

  SPENT_WORDS = %w[ spent spending expense expenses debit withdrawal out outflow payment - ]
  INCOME_WORDS = %w[ income earned credit deposit in inflow + ]
  NO_WORDS = %w[ no n false 0 - ]

  HEADER_WORDS = {
    "date" => %w[ date day when posted ],
    "name" => %w[ name description payee merchant item what store vendor details ],
    "amount" => %w[ amount cost price total spent value sum ],
    "spent_or_income" => %w[ type kind direction flow ],
    "category" => %w[ category categories cat group tag bucket ],
    "transfer" => %w[ transfer transfers ],
    "excluded" => %w[ excluded exclude ignore ignored hidden ],
    "note" => %w[ note notes memo comment comments ]
  }

  READS_AS = 0.8
  MOSTLY_SPENT = 0.9
  private_constant :KINDS, :POSITIVE_AMOUNTS, :SPENT_WORDS, :INCOME_WORDS, :NO_WORDS, :HEADER_WORDS, :READS_AS, :MOSTLY_SPENT

  class << self
    def guess(sheet)
      kinds = Array.new(sheet.headers.size, "skip")

      evidence(sheet).sort_by { |(kind, index), score| [ -score, KINDS.index(kind), index ] }.each do |(kind, index), _|
        if kinds[index] == "skip" && kinds.exclude?(kind)
          kinds[index] = kind
        end
      end

      amount_index = kinds.index("amount")
      new(kinds:, positive_amounts: positive_amounts_in(amount_index ? sheet.column(amount_index) : []))
    end

    def from(choice, sheet:)
      chosen = Array(choice[:columns])

      new(
        kinds: Array.new(sheet.headers.size) { |index| chosen[index].presence_in(KINDS) || "skip" },
        positive_amounts: choice[:positive_amounts].presence_in(POSITIVE_AMOUNTS) || "spent"
      )
    end

    def dump(columns)
      columns.to_h.to_json
    end

    def load(json)
      if json.present?
        new(**JSON.parse(json).symbolize_keys)
      end
    end

    private
      def evidence(sheet)
        cells = sheet.headers.each_index.map { |index| sheet.column(index).compact }
        dates = cells.map { |column| reads_as?(Import::DateFormat, column) }
        amounts = cells.map { |column| reads_as?(Import::AmountFormat, column) }
        words = cells.each_index.select { |index| !dates[index] && !amounts[index] && words?(cells[index]) }
        name_index = words.max_by { |index| cells[index].uniq.size }
        scores = Hash.new(0)

        sheet.headers.each_with_index do |header, index|
          header_scores(header).each { |kind, score| scores[[ kind, index ]] += score }

          if dates[index]
            scores[[ "date", index ]] += 1
          end

          if amounts[index]
            scores[[ "amount", index ]] += cents?(cells[index]) ? 1 : 0.5
          end

          if spent_or_income_values?(cells[index])
            scores[[ "spent_or_income", index ]] += 2
          else
            scores.delete([ "spent_or_income", index ])
          end

          if words.include?(index) && cells[index].uniq.size.between?(2, [ 20, sheet.rows.size / 20 ].max)
            scores[[ "category", index ]] += 1
          end

          if index == name_index
            scores[[ "name", index ]] += 1
          end
        end

        scores
      end

      def header_scores(header)
        words = header.downcase.scan(/\p{L}+/)

        HEADER_WORDS.filter_map do |kind, kind_words|
          if words.one? && kind_words.include?(words.first)
            [ kind, 3 ]
          elsif words.intersect?(kind_words)
            [ kind, 2 ]
          end
        end
      end

      def reads_as?(format, cells)
        reader = format.for(cells)
        cells.any? && cells.count { |cell| reader.read(cell) } >= cells.size * READS_AS
      end

      def cents?(cells)
        reader = Import::AmountFormat.for(cells)
        cells.any? { |cell| reader.read(cell).to_i % 100 != 0 }
      end

      def words?(cells)
        cells.count { |cell| cell.is_a?(String) && cell.match?(/\p{L}/) } * 2 > cells.size
      end

      def spent_or_income_values?(cells)
        values = cells.map { |cell| Import::Sheet.text(cell).downcase.squish }.uniq
        values.size.between?(1, 4) && values.all? { |value| SPENT_WORDS.include?(value) || INCOME_WORDS.include?(value) }
      end

      def positive_amounts_in(cells)
        reader = Import::AmountFormat.for(cells)
        amounts = cells.filter_map { |cell| reader.read(cell) }.reject(&:zero?)

        if amounts.any? && amounts.count(&:positive?) < amounts.size * MOSTLY_SPENT
          "income"
        else
          "spent"
        end
      end
  end

  def errors
    messages = []

    if kinds.exclude?("date")
      messages << "Choose a Date column."
    end

    if kinds.exclude?("amount")
      messages << "Choose an Amount column."
    end

    (kinds - [ "skip" ]).tally.each do |kind, count|
      if count > 1
        messages << "Only one column can be #{kind.humanize}."
      end
    end

    messages
  end

  def kind_at(index)
    kinds.fetch(index, "skip")
  end

  def needs_positive_amounts?
    kinds.exclude?("spent_or_income")
  end

  def read(sheet)
    if errors.any?
      return []
    end

    dates = Import::DateFormat.for(sheet.column(index_of("date")))
    amounts = Import::AmountFormat.for(sheet.column(index_of("amount")))
    spellings = {}
    ordinals = Hash.new(0)

    sheet.rows.filter_map do |sheet_row|
      if Import::DateFormat.dateless?(cell(sheet_row, "date"))
        next
      end

      occurred_on = dates.read(cell(sheet_row, "date"))
      cents = amounts.read(cell(sheet_row, "amount"))
      direction = direction_of(cell(sheet_row, "spent_or_income"))
      category_text = text(cell(sheet_row, "category"))
      name = text(cell(sheet_row, "name")) || category_text
      reason = unreadable_because(sheet_row, occurred_on:, cents:, direction:, name:)

      if reason
        Import::UnreadableRow.new(tab: sheet_row.tab, number: sheet_row.number, reason:)
      else
        identity = [ occurred_on, cents.abs, name.downcase.squish ]
        ordinals[identity] += 1
        transfer = yes?(cell(sheet_row, "transfer"))

        Import::Row.new(
          tab: sheet_row.tab,
          number: sheet_row.number,
          occurred_on:,
          name:,
          amount_in_cents: spent?(direction) ? -cents : cents,
          category_word: category_word(category_text, direction:, transfer:, spellings:),
          transfer:,
          excluded: yes?(cell(sheet_row, "excluded")),
          note: note(cell(sheet_row, "note")),
          key: Import::Row.key(*identity, ordinals[identity])
        )
      end
    end
  end

  private
    def index_of(kind)
      kinds.index(kind)
    end

    def cell(sheet_row, kind)
      index = index_of(kind)

      if index
        sheet_row.cells[index]
      end
    end

    def text(cell)
      Import::Sheet.text(cell)&.squish.presence
    end

    def note(cell)
      Import::Sheet.text(cell)&.strip.presence
    end

    def quoted(cell)
      "“#{Import::Sheet.text(cell)}”"
    end

    def unreadable_because(sheet_row, occurred_on:, cents:, direction:, name:)
      if occurred_on.nil?
        "can't read the date #{quoted(cell(sheet_row, "date"))}"
      elsif cell(sheet_row, "amount").nil?
        "there's no amount"
      elsif cents.nil?
        "can't read the amount #{quoted(cell(sheet_row, "amount"))}"
      elsif cents.zero?
        "the amount is 0"
      elsif direction.nil? && !needs_positive_amounts? && cell(sheet_row, "spent_or_income").nil?
        "there's no spent or income"
      elsif direction.nil? && !needs_positive_amounts?
        "#{quoted(cell(sheet_row, "spent_or_income"))} isn't spent or income"
      elsif name.nil?
        "there's no name"
      end
    end

    def direction_of(cell)
      word = Import::Sheet.text(cell).to_s.downcase.squish

      if SPENT_WORDS.include?(word)
        :spent
      elsif INCOME_WORDS.include?(word)
        :income
      end
    end

    def spent?(direction)
      if needs_positive_amounts?
        positive_amounts == "spent"
      else
        direction == :spent
      end
    end

    def category_word(category_text, direction:, transfer:, spellings:)
      if category_text && direction != :income && !transfer
        spellings[category_text.downcase] ||= category_text
      end
    end

    def yes?(cell)
      case cell
      when nil, false
        false
      when String
        NO_WORDS.exclude?(cell.downcase)
      when BigDecimal
        !cell.zero?
      else
        true
      end
    end
end
