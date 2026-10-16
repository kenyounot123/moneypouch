class Import::Sheet
  class Unreadable < StandardError; end

  Row = Data.define(:tab, :number, :cells)

  MAX_BYTES = 10.megabytes
  MAX_UNZIPPED_BYTES = 100.megabytes
  MAX_ZIP_ENTRIES = 200
  MAX_LINES = 50_000
  MAX_WIDTH = 40
  HEADER_SEARCH_ROWS = 20
  PREVIEW_ROWS = 8

  TOO_LARGE = "That file is over 10 MB. Split it or save fewer tabs."
  TOO_MANY_ROWS = "That file has over #{MAX_LINES.to_fs(:delimited)} rows. Split it into smaller files."
  TOO_MANY_COLUMNS = "That file has over #{MAX_WIDTH} columns. Delete the ones you don't need."
  NOT_A_SPREADSHEET = "Choose an Excel (.xlsx) or CSV file."
  OLD_EXCEL = "Save it as .xlsx or CSV first."
  NO_HEADER = "Couldn't find a header row with column names."
  NO_ROWS = "There are no rows under the header."

  BOMS = { "\xEF\xBB\xBF".b => Encoding::UTF_8, "\xFF\xFE".b => Encoding::UTF_16LE, "\xFE\xFF".b => Encoding::UTF_16BE }
  DELIMITERS = [ ",", ";", "\t" ]

  attr_reader :headers, :rows, :tabs, :skipped_tabs
  private_constant :MAX_BYTES, :MAX_UNZIPPED_BYTES, :MAX_ZIP_ENTRIES, :MAX_LINES, :MAX_WIDTH, :HEADER_SEARCH_ROWS, :PREVIEW_ROWS, :TOO_LARGE, :TOO_MANY_ROWS, :TOO_MANY_COLUMNS, :NOT_A_SPREADSHEET, :OLD_EXCEL, :NO_HEADER, :NO_ROWS, :BOMS, :DELIMITERS

  class << self
    def read(file)
      if file.size > MAX_BYTES
        raise Unreadable, TOO_LARGE
      end

      case File.extname(file.original_filename).downcase
      when ".xlsx"
        combine(xlsx_tabs(file.path))
      when ".csv", ".tsv", ".txt"
        combine([ [ nil, csv_lines(File.binread(file.path)) ] ])
      when ".xls", ".xlsm", ".numbers", ".ods"
        raise Unreadable, OLD_EXCEL
      else
        raise Unreadable, NOT_A_SPREADSHEET
      end
    end

    def text(cell)
      case cell
      when BigDecimal
        cell.frac.zero? ? cell.to_i.to_s : cell.to_s("F")
      when Date
        cell.iso8601
      when nil
        nil
      else
        cell.to_s
      end
    end

    def dump(sheet)
      {
        headers: sheet.headers,
        tabs: sheet.tabs,
        skipped_tabs: sheet.skipped_tabs,
        rows: sheet.rows.map { |row| [ row.tab, row.number, row.cells.map { |cell| dump_cell(cell) } ] }
      }.to_json
    end

    def load(json)
      if json.present?
        stored = JSON.parse(json, symbolize_names: true)

        new(
          headers: stored[:headers],
          tabs: stored[:tabs],
          skipped_tabs: stored[:skipped_tabs],
          rows: stored[:rows].map { |tab, number, cells| Row.new(tab:, number:, cells: cells.map { |cell| load_cell(cell) }) }
        )
      end
    end

    private
      def xlsx_tabs(path)
        check_zip(path)
        workbook = Roo::Excelx.new(path, file_warning: :ignore, no_hyperlinks: true, disable_html_wrapper: true)
        line_count = 0

        workbook.sheets.map do |name|
          lines = []

          workbook.each_row_streaming(sheet: name) do |roo_cells|
            line = xlsx_line(roo_cells)

            if line
              lines << line
              line_count += 1
            end

            if line_count > MAX_LINES
              raise Unreadable, TOO_MANY_ROWS
            end
          end

          [ name, lines ]
        end
      rescue Zip::Error, Nokogiri::XML::SyntaxError, Roo::Error, RuntimeError
        raise Unreadable, NOT_A_SPREADSHEET
      ensure
        workbook&.close
      end

      def check_zip(path)
        Zip::File.open(path) do |zip|
          if zip.size > MAX_ZIP_ENTRIES || zip.entries.sum(&:size) > MAX_UNZIPPED_BYTES
            raise Unreadable, TOO_LARGE
          elsif zip.find_entry("xl/vbaProject.bin")
            raise Unreadable, OLD_EXCEL
          elsif zip.find_entry("xl/workbook.xml").nil? || zip.find_entry("xl/_rels/workbook.xml.rels").nil?
            raise Unreadable, NOT_A_SPREADSHEET
          end
        end
      end

      def xlsx_line(roo_cells)
        cells = []
        number = nil

        roo_cells.each do |roo_cell|
          value = xlsx_value(roo_cell)

          if value.nil?
            next
          elsif roo_cell.coordinate.column > MAX_WIDTH
            raise Unreadable, TOO_MANY_COLUMNS
          end

          cells[roo_cell.coordinate.column - 1] = value
          number = roo_cell.coordinate.row
        end

        if number
          [ number, cells ]
        end
      end

      # Number cells read from the digits Excel stored, never through roo's Float.
      def xlsx_value(roo_cell)
        case roo_cell
        when Roo::Excelx::Cell::Time
          nil
        when Roo::Excelx::Cell::DateTime
          roo_cell.value.to_date
        when Roo::Excelx::Cell::Number
          BigDecimal(roo_cell.cell_value, exception: false) || roo_cell.cell_value
        when Roo::Excelx::Cell::Boolean
          roo_cell.value
        when Roo::Excelx::Cell::String
          roo_cell.value.to_s.strip.presence
        end
      end

      def csv_lines(bytes)
        text = decode(bytes)
        lines = []

        CSV.parse(text, col_sep: delimiter_in(text), liberal_parsing: true) do |fields|
          if lines.size == MAX_LINES
            raise Unreadable, TOO_MANY_ROWS
          end

          lines << [ lines.size + 1, fields.map { |field| field&.strip.presence } ]
        end

        lines
      rescue CSV::MalformedCSVError
        raise Unreadable, NOT_A_SPREADSHEET
      end

      def decode(bytes)
        bom, encoding = BOMS.find { |mark, _| bytes.start_with?(mark) }

        if bom
          text = bytes.byteslice(bom.bytesize..).force_encoding(encoding)
        else
          text = bytes.force_encoding(Encoding::UTF_8)

          if !text.valid_encoding?
            text.force_encoding(Encoding::Windows_1252)
          end
        end

        text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace).scrub
      end

      def delimiter_in(text)
        first_line = text.each_line.find { |line| line.strip.present? }.to_s
        DELIMITERS.max_by { |delimiter| first_line.count(delimiter) }
      end

      def combine(tabs)
        found = tabs.filter_map { |name, lines| split_at_header(name, lines) }
        groups = found.select { |tab| tab[:header] }.group_by { |tab| header_key(tab[:header]) }.values

        if groups.empty?
          raise Unreadable, NO_HEADER
        end

        kept = groups.max_by { |group| group.sum { |tab| tab[:rows].size } }
        rows = kept.flat_map { |tab| tab[:rows] }

        if rows.empty?
          raise Unreadable, NO_ROWS
        end

        new(
          headers: labels_for(kept.first[:header], width: rows.map { |row| row.cells.size }.max),
          rows:,
          tabs: kept.filter_map { |tab| tab[:name] },
          skipped_tabs: (found - kept).filter_map { |tab| tab[:name] }
        )
      end

      def split_at_header(name, lines)
        filled = lines.select { |_, cells| cells.any? }.map { |number, cells| [ number, trimmed(cells) ] }

        if filled.any?
          header_index = filled.first(HEADER_SEARCH_ROWS).index { |_, cells| header?(cells) }

          if header_index
            rows = filled.drop(header_index + 1).map { |number, cells| Row.new(tab: name, number:, cells:) }
            { name:, header: filled[header_index].last, rows: }
          else
            { name:, header: nil, rows: [] }
          end
        end
      end

      def trimmed(cells)
        cells = cells.dup

        while cells.any? && cells.last.nil?
          cells.pop
        end

        if cells.size > MAX_WIDTH
          raise Unreadable, TOO_MANY_COLUMNS
        end

        cells
      end

      def header?(cells)
        filled = cells.compact
        words = filled.count { |cell| cell.is_a?(String) && cell.match?(/\p{L}/) && !cell.match?(/\d/) }

        filled.size >= 2 && words * 2 > filled.size
      end

      def header_key(header)
        header.map { |cell| text(cell)&.downcase&.squish }
      end

      def labels_for(header, width:)
        Array.new([ header.size, width ].max) do |index|
          text(header[index]) || "Column #{column_letter(index)}"
        end
      end

      def column_letter(index)
        if index < 26
          ("A".ord + index).chr
        else
          column_letter(index / 26 - 1) + column_letter(index % 26)
        end
      end

      def dump_cell(cell)
        case cell
        when Date
          { d: cell.iso8601 }
        when BigDecimal
          { n: cell.to_s("F") }
        else
          cell
        end
      end

      def load_cell(cell)
        case cell
        in { d: date }
          Date.iso8601(date)
        in { n: number }
          BigDecimal(number)
        else
          cell
        end
      end
  end

  def initialize(headers:, rows:, tabs:, skipped_tabs:)
    @headers, @rows, @tabs, @skipped_tabs = headers, rows, tabs, skipped_tabs
  end

  def preview
    rows.first(PREVIEW_ROWS)
  end

  def column(index)
    rows.map { |row| row.cells[index] }
  end
end
