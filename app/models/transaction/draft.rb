class Transaction::Draft
  MISSING_AMOUNT = "Type an amount, like 5.50"
  MISSING_NAME = "Type a name, like coffee"

  Reading = Data.define(:name, :amount_in_cents, :category_word, :occurred_on, :dated, :errors)

  module Grammar
    MONTHS = Date::MONTHNAMES.compact.each.with_index(1)
      .flat_map { |month, number| [ [ month.downcase, number ], [ month[0, 3].downcase, number ] ] }
      .to_h.merge("sept" => 9).freeze
    FULL_WEEKDAYS = Date::DAYNAMES.map(&:downcase).each_with_index.to_h.freeze
    DAY = /\A(\d{1,2})(?:st|nd|rd|th)?\z/i
    YEAR = /\A\d{4}\z/
    SLASH_DATE = %r{\A(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?\z}
    ISO_DATE = /\A(\d{4})-(\d{1,2})-(\d{1,2})\z/
    CATEGORY = /\A#(\S*?)[[:punct:]]*\z/
    AMOUNT = /\A(?<sign>[+-])?(?<symbol>\$)?(?<dollars>\d{1,3}(?:,\d{3})+|\d+)?(?:\.(?<cents>\d{1,2}))?\z/
    MAX_DOLLAR_DIGITS = 7
    LEAP_CYCLE_YEARS = 4

    class << self
      def read(line, today:)
        words = line.squish.split(" ")
        dated_on = month_name_date(words, today) || numeric_date(words, today) || relative_date(words, today)
        category_word = take(words) { |word| word[CATEGORY, 1].presence }
        words.delete("#")
        amount_in_cents = take_amount(words)
        name = words.join(" ")
        errors = [ (MISSING_AMOUNT unless amount_in_cents), (MISSING_NAME if name.empty?) ].compact.freeze

        Reading.new(name:, amount_in_cents:, category_word:, occurred_on: dated_on || today, dated: dated_on.present?, errors:)
      end

      private
        def take(words)
          words.each_with_index do |word, index|
            if (value = yield(word))
              words.delete_at(index)
              return value
            end
          end
          nil
        end

        def month_name_date(words, today)
          index = words.each_cons(2).find_index { |month, day| MONTHS.key?(month.downcase) && day.match?(DAY) } or return
          month, day, year = words[index, 3]
          month, day = MONTHS[month.downcase], day[DAY, 1].to_i
          year = typed_year(year, today)
          date = year ? dated(year, month, day, today) : latest(month, day, today)
          width = year ? 3 : 2
          words[index, width] = date ? [] : [ words[index, width].join(" ") ]
          date
        end

        def numeric_date(words, today)
          take(words) do |word|
            if (iso = ISO_DATE.match(word))
              dated(*iso.captures.map(&:to_i), today)
            elsif (slash = SLASH_DATE.match(word))
              month, day, year = slash.captures
              if year
                dated(year.to_i + (year.length == 2 ? 2000 : 0), month.to_i, day.to_i, today)
              else
                latest(month.to_i, day.to_i, today)
              end
            end
          end
        end

        def relative_date(words, today)
          take(words) do |word|
            word = word.downcase
            case word
            when "today" then today
            when "yesterday" then today.prev_day
            else today - (today.wday - FULL_WEEKDAYS[word]) % 7 if FULL_WEEKDAYS.key?(word)
            end
          end
        end

        def typed_year(word, today)
          word.to_i if word&.match?(YEAR) && years(today).cover?(word.to_i)
        end

        def years(today)
          (today.year - 20)..(today.year + 1)
        end

        def dated(year, month, day, today)
          return unless Date.valid_date?(year, month, day)
          date = Date.new(year, month, day)
          date if date.between?(today.prev_year(20), today.next_year)
        end

        def latest(month, day, today)
          today.year.downto(today.year - LEAP_CYCLE_YEARS)
            .filter_map { |year| Date.new(year, month, day) if Date.valid_date?(year, month, day) }
            .find { |date| date <= today }
        end

        def take_amount(words)
          amounts = words.each_with_index.filter_map do |word, index|
            cents, marked = money(word)
            [ index, cents, marked ] if cents
          end
          index, cents, = amounts.find { |_, _, marked| marked } || amounts.last
          words.delete_at(index) if index
          cents
        end

        def money(word)
          amount = AMOUNT.match(word) or return
          dollars = amount[:dollars].to_s.delete(",")
          return if dollars.length > MAX_DOLLAR_DIGITS
          cents = dollars.to_i * 100 + amount[:cents].to_s.ljust(2, "0").to_i
          return if cents.zero?
          marked = [ amount[:sign], amount[:symbol], amount[:cents] ].any? || amount[:dollars].to_s.include?(",")
          [ amount[:sign] == "+" ? cents : -cents, marked ]
        end
    end
  end

  def self.parse(line, user:, today:, complete: false, editing: nil)
    line = line.to_s
    reading = Grammar.read(line, today:)
    typed = line.lstrip
    completed = user.transactions.name_starting_with(typed) if complete && completable?(typed)
    category = resolve_category(reading.category_word, completed || reading.name, user, editing)
    new(line:, reading:, category:, completion: completed)
  end

  def self.completable?(typed)
    typed.gsub(/\s/, "").length >= 2 && !typed.match?(/[\d#@$+]/)
  end
  private_class_method :completable?

  def self.resolve_category(category_word, name, user, editing)
    if category_word
      user.categories.named(category_word).first || Category.new(user:, name: category_word)
    elsif name.present?
      user.transactions.excluding(editing).last_category_for(name)
    end
  end
  private_class_method :resolve_category

  attr_reader :line, :category, :completion

  delegate :name, :amount_in_cents, :category_word, :occurred_on, :errors, to: :@reading

  def initialize(line:, reading:, category:, completion: nil)
    @line = line
    @reading = reading
    @category = category
    @completion = completion
  end

  def category_name
    category&.name
  end

  def dated?
    @reading.dated
  end

  def inferred?
    category.present? && @reading.category_word.nil?
  end

  def valid?
    errors.empty?
  end

  def money_in?
    amount_in_cents.to_i.positive?
  end

  def attributes
    { name:, amount_in_cents:, occurred_on:, category:, line: }
  end
end
