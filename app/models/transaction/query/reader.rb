# Turns the words of a search into clauses. Each kind of token is a pattern and the method that reads it.
class Transaction::Query::Reader
  WORDS = /"[^"]*"?|\S+/
  NUMBER = /(\d+(?:\.\d{1,2})?)/
  TOKENS = [
    [ /\A#(.*)\z/, :category ],
    [ /\Ain:(.*)\z/i, :account ],
    [ /\A([<>])\$?#{NUMBER}\z/, :compared ],
    [ /\A\$?#{NUMBER}\.\.\$?#{NUMBER}\z/, :between ],
    [ /\A(?:=\$?|\$)#{NUMBER}\z/, :exactly ],
    [ /\A@(.+)\z/, :date ],
    [ /\A[?+-]\z/, :status ]
  ]
  STATUSES = {
    "?" => [ "Needs a category", :needing_category ],
    "+" => [ "Money in", :money_in ],
    "-" => [ "Money out", :money_out ]
  }
  RANGES = {
    "today" => [ "Today", ->(today) { today..today } ],
    "yesterday" => [ "Yesterday", ->(today) { (today - 1)..(today - 1) } ],
    "7d" => [ "Last 7 days", ->(today) { (today - 6)..today } ],
    "30d" => [ "Last 30 days", ->(today) { (today - 29)..today } ],
    "90d" => [ "Last 90 days", ->(today) { (today - 89)..today } ],
    "year" => [ "This year", ->(today) { today.beginning_of_year..today } ]
  }
  MONTH_NAMES = Date::MONTHNAMES.compact.map(&:downcase)

  def initialize(user:, today:)
    @user = user
    @today = today
  end

  def clauses(string)
    string.to_s.scan(WORDS).filter_map { |raw| read(raw) }
  end

  private
    attr_reader :user, :today

    def read(raw)
      pattern, kind = TOKENS.find { |pattern, _| pattern.match?(raw) }

      if kind
        send(kind, raw, pattern.match(raw))
      else
        text(raw)
      end
    end

    def text(raw)
      phrase = raw.delete_prefix('"').delete_suffix('"').squish
      clause(:text, raw, "“#{phrase}”", ->(transactions) { transactions.matching(phrase) }) if phrase.present?
    end

    def category(raw, match)
      category = closest(categories, match[1], :name)

      if category
        clause(:category, raw, category.name, ->(transactions) { transactions.in_category(category) })
      else
        problem(:category, raw, "No category matches “#{match[1]}”.")
      end
    end

    def account(raw, match)
      account = account_for(match[1])

      if Transaction::Query.squash(match[1]) == "typed"
        clause(:account, raw, "Typed in", ->(transactions) { transactions.typed_in })
      elsif account
        clause(:account, raw, account.full_name, ->(transactions) { transactions.from_bank_account(account) })
      else
        problem(:account, raw, "No account matches “#{match[1]}”.")
      end
    end

    def account_for(word)
      closest(accounts, word, :full_name) { |account, key| words(account.full_name).any? { |name_word| name_word.start_with?(key) } }
    end

    def compared(raw, match)
      cents = cents(match[2])
      over = match[1] == ">"
      label = "#{over ? "Over" : "Under"} #{dollars(cents)}"
      clause(:amount, raw, label, ->(transactions) { transactions.where(over ? absolute.gt(cents) : absolute.lt(cents)) })
    end

    def between(raw, match)
      low, high = [ cents(match[1]), cents(match[2]) ].minmax
      clause(:amount, raw, "#{dollars(low)}–#{dollars(high)}", ->(transactions) { transactions.where(absolute.between(low..high)) })
    end

    def exactly(raw, match)
      cents = cents(match[1])
      clause(:amount, raw, dollars(cents), ->(transactions) { transactions.where(absolute.eq(cents)) })
    end

    def status(raw, _match)
      label, scope = STATUSES.fetch(raw)
      clause(:status, raw, label, ->(transactions) { transactions.public_send(scope) })
    end

    def date(raw, match)
      word = match[1].downcase
      label, range = RANGES[word]
      month = month_named(word)

      if range
        date_clause(raw, label, range.(today))
      elsif month
        calendar_month(raw, month)
      else
        problem(:date, raw, "“#{match[1]}” isn’t a date.")
      end
    end

    def date_clause(raw, label, dates, month: nil)
      Transaction::Query::Clause.new(part: part(:date, raw, label), apply: ->(transactions) { transactions.occurred_in(dates) }, dates:, month:)
    end

    def calendar_month(raw, month)
      if month > today
        problem(:date, raw, "#{month.strftime("%B %Y")} hasn’t started.")
      else
        period = Period.new("month", today:, on: month)
        date_clause(raw, month.strftime("%B %Y"), period.range, month: period)
      end
    end

    def month_named(word)
      explicit = word.match(/\A(\d{4})-(\d{2})\z/)
      number = MONTH_NAMES.index { |name| name.start_with?(word) } if word.length >= 3

      if explicit
        Date.new(explicit[1].to_i, explicit[2].to_i, 1)
      elsif number
        Date.new(today.year - (number + 1 > today.month ? 1 : 0), number + 1, 1)
      end
    rescue Date::Error
    end

    def clause(kind, raw, label, apply)
      Transaction::Query::Clause.new(part: part(kind, raw, label), apply:)
    end

    def problem(kind, raw, sentence)
      Transaction::Query::Clause.new(part: part(kind, raw, raw, sentence))
    end

    def part(kind, raw, label, problem = nil)
      Transaction::Query::Part.new(kind:, raw:, label:, problem:)
    end

    def categories
      @categories ||= user.categories.alphabetically.to_a
    end

    def accounts
      @accounts ||= user.bank_accounts.to_a.sort_by { |account| Transaction::Query.squash(account.full_name) }
    end

    def closest(records, word, name)
      key = Transaction::Query.squash(word)
      squashed = ->(record) { Transaction::Query.squash(record.public_send(name)) }

      unless key.empty?
        records.find { |record| squashed.(record) == key } ||
          records.find { |record| squashed.(record).start_with?(key) } ||
          (records.find { |record| yield record, key } if block_given?)
      end
    end

    def words(name)
      name.downcase.scan(/[\p{L}\p{N}]+/)
    end

    def cents(number)
      (number.to_d * 100).to_i
    end

    def dollars(cents)
      whole, rest = cents.divmod(100)
      delimited = ActiveSupport::NumberHelper.number_to_delimited(whole)
      rest.zero? ? "$#{delimited}" : format("$%s.%02d", delimited, rest)
    end

    def absolute
      Arel::Nodes::NamedFunction.new("ABS", [ Transaction.arel_table[:amount_in_cents] ])
    end
end
