class Import::AmountFormat
  NUMBER = /\A\d+(\.\d+)?\z/
  CURRENCY = /\p{Sc}|(?<!\p{L})\p{L}{1,3}\.?(?!\p{L})/
  DECIMAL = /[.,](?=\d{1,2}\D*\z)/

  attr_reader :decimal_mark

  # "1.234,56" and "12,50" vote for ","; "1,234" votes for neither.
  def self.for(cells)
    marks = cells.grep(String).filter_map { |text| text[DECIMAL] }

    if marks.count(",") > marks.count(".")
      new(",")
    else
      new(".")
    end
  end

  def initialize(decimal_mark)
    @decimal_mark = decimal_mark
  end

  def read(cell)
    case cell
    when BigDecimal
      cents(cell)
    when String
      read_text(cell)
    end
  end

  private
    def read_text(text)
      bare = text.gsub(CURRENCY, "").gsub(/[[:space:]']/, "").tr("−", "-")
      unsigned = bare[/\A\((.+)\)\z/, 1] || bare[/\A-(.+)\z/, 1] || bare[/\A(.+)-\z/, 1]
      cents = number_in(unsigned || bare.delete_prefix("+"))

      if cents && unsigned
        -cents
      else
        cents
      end
    end

    def number_in(text)
      number = text.delete(thousands_mark).tr(decimal_mark, ".")

      if number.match?(NUMBER)
        cents(BigDecimal(number))
      end
    end

    def thousands_mark
      if decimal_mark == ","
        "."
      else
        ","
      end
    end

    # Rounds as Simplefin::Client#cents does, so a bank sync can match the row to the cent.
    def cents(number)
      (number * 100).round(0, half: :even).to_i
    end
end
