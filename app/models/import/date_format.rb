class Import::DateFormat
  CANDIDATES = {
    "iso" => [ %r{\A\d{4}/\d{1,2}/\d{1,2}\z}, [ "%Y/%m/%d" ] ],
    "month_first" => [ %r{\A\d{1,2}/\d{1,2}/\d{2,4}\z}, [ "%m/%d/%Y", "%m/%d/%y" ] ],
    "day_first" => [ %r{\A\d{1,2}/\d{1,2}/\d{2,4}\z}, [ "%d/%m/%Y", "%d/%m/%y" ] ],
    "month_name" => [ /\A\p{L}{3,9} \d{1,2} \d{2,4}\z/, [ "%b %d %Y", "%b %d %y" ] ],
    "day_month_name" => [ /\A\d{1,2} \p{L}{3,9} \d{2,4}\z/, [ "%d %b %Y", "%d %b %y" ] ]
  }
  TIME_OF_DAY = /(\s+|T)\d{1,2}:\d{2}.*\z/
  EXCEL_EPOCH = Date.new(1899, 12, 30)
  EXCEL_SERIALS = 20_000..80_000
  EARLIEST = Date.new(1970, 1, 1)

  attr_reader :name

  def self.dateless?(cell)
    case cell
    when nil, true, false
      true
    when String
      !cell.match?(/\d/)
    else
      false
    end
  end

  def self.for(cells)
    texts = cells.grep(String)
    CANDIDATES.keys.map { |name| new(name) }.max_by { |format| texts.count { |text| format.read(text) } }
  end

  def initialize(name)
    @name = name
  end

  def read(cell)
    case cell
    when Date
      within_range(cell)
    when BigDecimal
      from_excel_serial(cell)
    when String
      parse(normalize(cell))
    end
  end

  private
    def normalize(text)
      text.sub(TIME_OF_DAY, "").squish.gsub(%r{(?<=\d)[./-](?=\d)}, "/").tr(".,-", "   ").squish
    end

    def parse(text)
      gate, patterns = CANDIDATES.fetch(name)

      if text.match?(gate)
        patterns.filter_map { |pattern| strptime(text, pattern) }.first
      end
    end

    # "%Y" reads "24" as the year 24, which the range turns away so "%y" gets its turn.
    def strptime(text, pattern)
      within_range(Date.strptime(text, pattern))
    rescue Date::Error
      nil
    end

    def from_excel_serial(number)
      if EXCEL_SERIALS.cover?(number)
        within_range(EXCEL_EPOCH + number.floor)
      end
    end

    def within_range(date)
      if date.between?(EARLIEST, Date.current.next_year)
        date
      end
    end
end
