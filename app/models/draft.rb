class Draft
  MISSING_AMOUNT = "Add an amount"
  MISSING_NAME = "Add a name"

  Reading = Data.define(:name, :amount_in_cents, :category_word, :occurred_on, :errors)

  # Rules run in a fixed order, and each takes only the first word it matches, so
  # "sep 26 rent 1650" reads 26 as a day and "7 eleven 5" keeps "eleven 5" as the name.
  module Grammar
    MONTHS = Date::MONTHNAMES.compact.each.with_index(1)
      .flat_map { |month, number| [ [ month.downcase, number ], [ month[0, 3].downcase, number ] ] }
      .to_h.merge("sept" => 9).freeze
    # Full names only, since "sat", "sun", and "wed" are also words in names.
    WEEKDAYS = Date::DAYNAMES.map(&:downcase).each_with_index.to_h.freeze
    DAY = /\A\d{1,2}\z/
    SLASH_DATE = %r{\A(\d{1,2})/(\d{1,2})\z}
    ISO_DATE = /\A(\d{4})-(\d{1,2})-(\d{1,2})\z/
    CATEGORY = /\A#(\S+)\z/
    # Seven dollar digits keep the cents inside a 32-bit integer column.
    AMOUNT = /\A(?<sign>\+)?\$?(?<dollars>\d{1,7})(?:\.(?<cents>\d{1,2}))?\z/

    class << self
      def read(line, today:)
        words = line.squish.split(" ")
        occurred_on = month_name_date(words, today) || numeric_date(words, today) || relative_date(words, today) || today
        category_word = take(words) { |word| word[CATEGORY, 1] }
        amount_in_cents = take(words) { |word| cents(word)&.nonzero? }
        name = words.join(" ")
        errors = [ (MISSING_AMOUNT unless amount_in_cents), (MISSING_NAME if name.empty?) ].compact.freeze

        Reading.new(name:, amount_in_cents:, category_word:, occurred_on:, errors:)
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
          month, day = words[index, 2]
          date = latest(MONTHS[month.downcase], day.to_i, today)
          # An impossible pair like "feb 30" stays in the name as one word, so its day cannot become the amount.
          words[index, 2] = date ? [] : [ "#{month} #{day}" ]
          date
        end

        def numeric_date(words, today)
          take(words) do |word|
            if (iso = ISO_DATE.match(word))
              year, month, day = iso.captures.map(&:to_i)
              Date.new(year, month, day) if Date.valid_date?(year, month, day)
            elsif (slash = SLASH_DATE.match(word))
              latest(*slash.captures.map(&:to_i), today)
            end
          end
        end

        def relative_date(words, today)
          take(words) do |word|
            word = word.downcase
            case word
            when "today" then today
            when "yesterday" then today.prev_day
            else today - (today.wday - WEEKDAYS[word]) % 7 if WEEKDAYS.key?(word)
            end
          end
        end

        # Walks back past non-leap years so "feb 29" lands on the last leap day.
        def latest(month, day, today)
          today.year.downto(today.year - 4)
            .filter_map { |year| Date.new(year, month, day) if Date.valid_date?(year, month, day) }
            .find { |date| date <= today }
        end

        def cents(word)
          amount = AMOUNT.match(word) or return
          cents = amount[:dollars].to_i * 100 + amount[:cents].to_s.ljust(2, "0").to_i
          amount[:sign] ? cents : -cents
        end
    end
  end

  # excluding is the row being edited, so an edit cannot infer its category from itself.
  def self.parse(line, user:, today:, excluding: nil)
    line = line.to_s
    reading = Grammar.read(line, today:)
    new(line:, reading:, category: resolve_category(reading, user, excluding))
  end

  # One query either way. A first-use category comes back unsaved, so the transaction's
  # save persists both together and a preview never writes.
  def self.resolve_category(reading, user, excluding)
    if reading.errors.any?
      nil
    elsif reading.category_word
      user.categories.named(reading.category_word).first || Category.new(user:, name: reading.category_word)
    else
      user.transactions.eager_load(:category)
        .where("lower(transactions.name) = ?", reading.name.downcase(:ascii))
        .where.not(id: excluding)
        .order(occurred_on: :desc, id: :desc)
        .first&.category
    end
  end
  private_class_method :resolve_category

  attr_reader :line, :category

  delegate :name, :amount_in_cents, :occurred_on, :errors, to: :@reading

  def initialize(line:, reading:, category:)
    @line = line
    @reading = reading
    @category = category
  end

  def category_name = category&.name

  def inferred? = category.present? && @reading.category_word.nil?

  def valid? = errors.empty?

  def money_in? = amount_in_cents.to_i.positive?

  def attributes
    { name:, amount_in_cents:, occurred_on:, category:, line: }
  end

  def to_partial_path = "drafts/draft"
end
