# What the Transactions page search box holds, like `#dining >30 in:amex @sep`: ordered tokens read against one user's categories and bank accounts.
class Transaction::Query
  Part = Data.define(:kind, :raw, :label, :problem)

  Clause = Data.define(:part, :apply, :dates, :month) do
    def initialize(part:, apply: nil, dates: nil, month: nil)
      super
    end

    def valid?
      part.problem.nil?
    end
  end

  NEEDS = "?"
  ORED = %i[ category account ]
  SINGLE = %i[ amount date ]

  def self.parse(string, user:, today:)
    new(Reader.new(user:, today:).clauses(string))
  end

  def self.blank
    new([])
  end

  def self.squash(name)
    name.downcase.gsub(/[^\p{L}\p{N}]/, "")
  end

  def self.category_token(category)
    "##{squash(category.name)}"
  end

  def self.account_token(bank_account)
    "in:#{squash(bank_account.full_name)}"
  end

  def self.text_token(name)
    %("#{name.delete('"')}")
  end

  def initialize(clauses)
    @clauses = supersede(clauses)
  end

  def parts
    @clauses.map(&:part)
  end

  def include?(raw)
    raws.include?(raw)
  end

  def filtering?
    valid.any?
  end

  def dates
    dated&.dates
  end

  def month
    dated&.month
  end

  def scope(transactions, except: nil)
    clauses = valid.reject { |clause| clause.part.raw == except }
    ored, anded = clauses.partition { |clause| ORED.include?(clause.part.kind) }
    narrowed = anded.reduce(transactions) { |scoped, clause| clause.apply.(scoped) }

    ored.group_by { |clause| clause.part.kind }.values.reduce(narrowed) do |scoped, group|
      scoped.and(group.map { |clause| clause.apply.(transactions) }.reduce(:or))
    end
  end

  def adding(raw)
    [ *raws, raw ].join(" ")
  end

  def without(index)
    raws.each_with_index.reject { |_, at| at == index }.map(&:first).join(" ")
  end

  def toggle(raw)
    if include?(raw)
      (raws - [ raw ]).join(" ")
    else
      adding(raw)
    end
  end

  def without_dates
    undated.join(" ")
  end

  def with_month(period)
    [ *undated, period.first_day.strftime("@%Y-%m") ].join(" ")
  end

  def to_s
    raws.join(" ")
  end

  private
    def raws
      parts.map(&:raw)
    end

    def undated
      parts.reject { |part| part.kind == :date }.map(&:raw)
    end

    def valid
      @clauses.select(&:valid?)
    end

    def dated
      valid.find(&:dates)
    end

    def supersede(clauses)
      seen = Set.new

      clauses.reverse.map do |clause|
        kind = clause.part.kind
        if clause.valid? && SINGLE.include?(kind) && !seen.add?(kind)
          clause.with(part: clause.part.with(problem: "Replaced by a later #{kind}."))
        else
          clause
        end
      end.reverse
    end
end
