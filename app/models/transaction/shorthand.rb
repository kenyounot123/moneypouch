module Transaction::Shorthand
  MISSING_AMOUNT = "Type an amount, like 5.50"
  MISSING_NAME = "Type a name, like coffee"

  Parts = Data.define(:name, :amount_in_cents, :category_word, :occurred_on, :dated, :tokens, :errors)
  Word = Data.define(:text, :start)
  Token = Data.define(:kind, :start, :finish)

  MONTHS = Date::MONTHNAMES.compact.each.with_index(1)
    .flat_map { |month, number| [ [ month.downcase, number ], [ month[0, 3].downcase, number ] ] }
    .to_h.merge("sept" => 9).freeze
  FULL_WEEKDAYS = Date::DAYNAMES.map(&:downcase).each_with_index.to_h.freeze
  MARKERS = { "#" => :category, "@" => :date }.freeze
  DAY = /\A(\d{1,2})(?:st|nd|rd|th)?\z/i
  YEAR = /\A\d{4}\z/
  SLASH_DATE = %r{\A@?(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?\z}
  ISO_DATE = /\A@?(\d{4})-(\d{1,2})-(\d{1,2})\z/
  CATEGORY = /\A#(\S*?)[[:punct:]]*\z/
  AMOUNT = /\A(?<sign>[+-])?(?<symbol>\$)?(?<dollars>\d{1,3}(?:,\d{3})+|\d+)?(?:\.(?<cents>\d{1,2}))?\z/
  MAX_DOLLAR_DIGITS = 7
  LEAP_CYCLE_YEARS = 4

  class << self
    def read(shorthand, today:)
      words = shorthand.to_s.enum_for(:scan, /[^[:space:]]+/).map { Word.new(text: $~[0], start: $~.begin(0)) }
      tokens = []
      dated_on = month_name_date(words, today, tokens) || numeric_date(words, today, tokens) || relative_date(words, today, tokens)
      category_word = take(words, :category, tokens) { |word| word[CATEGORY, 1].presence }
      take_markers(words, tokens)
      amount_in_cents = take_amount(words, tokens)
      name = words.map(&:text).join(" ")
      errors = [ (MISSING_AMOUNT unless amount_in_cents), (MISSING_NAME if name.empty?) ].compact.freeze

      Parts.new(name:, amount_in_cents:, category_word:, occurred_on: dated_on || today, dated: dated_on.present?,
        tokens: tokens.sort_by(&:start).freeze, errors:)
    end

    private
      def take(words, kind, tokens)
        words.each_with_index do |word, index|
          value = yield(word.text)

          if value
            words.delete_at(index)
            tokens << token(kind, word, word)
            return value
          end
        end
        nil
      end

      def token(kind, first, last)
        Token.new(kind:, start: first.start, finish: last.start + last.text.length)
      end

      def take_markers(words, tokens)
        words.reject! do |word|
          kind = MARKERS[word.text]

          if kind
            tokens << token(kind, word, word)
            true
          end
        end
      end

      def month_name_date(words, today, tokens)
        index = words.each_cons(2).find_index { |month, day| month_number(month.text) && day.text.match?(DAY) }

        if index.nil?
          return
        end

        month, day, year = words[index, 3]

        if year && !typed_year(year.text, today)
          year = nil
        end

        date = date_on(month, day, year, today)
        taken = [ month, day, year ].compact

        if date
          words[index, taken.size] = []
          tokens << token(:date, taken.first, taken.last)
        else
          words[index, taken.size] = [ Word.new(text: taken.map(&:text).join(" "), start: month.start) ]
        end

        date
      end

      def date_on(month, day, year, today)
        month, day = month_number(month.text), day.text[DAY, 1].to_i

        if year
          dated(typed_year(year.text, today), month, day, today)
        else
          latest(month, day, today)
        end
      end

      def month_number(word)
        MONTHS[word.downcase.delete_prefix("@")]
      end

      def numeric_date(words, today, tokens)
        take(words, :date, tokens) do |word|
          iso = ISO_DATE.match(word)
          slash = SLASH_DATE.match(word)

          if iso
            dated(*iso.captures.map(&:to_i), today)
          elsif slash
            month, day, year = slash.captures

            if year
              dated(year.to_i + (year.length == 2 ? 2000 : 0), month.to_i, day.to_i, today)
            else
              latest(month.to_i, day.to_i, today)
            end
          end
        end
      end

      def relative_date(words, today, tokens)
        take(words, :date, tokens) do |word|
          word = word.downcase.delete_prefix("@")

          if word == "today"
            today
          elsif word == "yesterday"
            today.prev_day
          elsif FULL_WEEKDAYS.key?(word)
            today - (today.wday - FULL_WEEKDAYS[word]) % 7
          end
        end
      end

      def typed_year(word, today)
        if word&.match?(YEAR) && years(today).cover?(word.to_i)
          word.to_i
        end
      end

      def years(today)
        (today.year - 20)..(today.year + 1)
      end

      def dated(year, month, day, today)
        if Date.valid_date?(year, month, day)
          date = Date.new(year, month, day)

          if date.between?(today.prev_year(20), today.next_year)
            date
          end
        end
      end

      def latest(month, day, today)
        today.year.downto(today.year - LEAP_CYCLE_YEARS)
          .select { |year| Date.valid_date?(year, month, day) }
          .map { |year| Date.new(year, month, day) }
          .find { |date| date <= today }
      end

      def take_amount(words, tokens)
        amounts = words.each_with_index.filter_map do |word, index|
          cents, marked = money(word.text)

          if cents
            [ index, cents, marked ]
          end
        end

        index, cents, = amounts.find { |_, _, marked| marked } || amounts.last

        if index
          word = words.delete_at(index)
          tokens << token(:amount, word, word)
        end
        cents
      end

      def money(word)
        amount = AMOUNT.match(word)

        if amount
          dollars = amount[:dollars].to_s.delete(",")
          cents = dollars.to_i * 100 + amount[:cents].to_s.ljust(2, "0").to_i

          if dollars.length <= MAX_DOLLAR_DIGITS && cents.nonzero?
            marked = [ amount[:sign], amount[:symbol], amount[:cents] ].any? || amount[:dollars].to_s.include?(",")
            [ amount[:sign] == "+" ? cents : -cents, marked ]
          end
        end
      end
  end
end
