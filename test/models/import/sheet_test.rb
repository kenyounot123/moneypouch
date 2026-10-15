require "test_helper"

class Import::SheetTest < ActiveSupport::TestCase
  test "a CSV reads as its header and the filled rows under it, numbered as a spreadsheet app shows them" do
    sheet = Import::Sheet.read(import_file("personal.csv"))

    assert_equal [ "Date", "Item", "Category", "Amount", "Excluded", "Note" ], sheet.headers
    assert_equal [ 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15 ], sheet.rows.map(&:number)
    assert_equal [ "2024-10-05", "Blue Bottle", "Coffee", "-5.50", nil, "refund" ], sheet.rows[6].cells
    assert_equal [ [], [] ], [ sheet.tabs, sheet.skipped_tabs ]
  end

  test "a CSV that isn't UTF-8 reads as Windows-1252" do
    sheet = Import::Sheet.read(import_file("bank.csv"))

    assert_equal [ "10/01/2024", "CAFÉ ROMA", "-4.50", "995.50" ], sheet.rows.first.cells
  end

  test "a CSV with a byte order mark and semicolons splits on the semicolons" do
    sheet = Import::Sheet.read(import_file("european.csv"))

    assert_equal [ "Datum", "Beschreibung", "Betrag", "Kategorie" ], sheet.headers
    assert_equal [ "02.10.2024", "Bäckerei", "-3,50", "Essen" ], sheet.rows.first.cells
  end

  test "a tab-separated UTF-16 export reads like any CSV" do
    text = "Date\tName\tAmount\r\n2024-10-01\tCafé\t5.50\r\n".encode(Encoding::UTF_16LE)
    sheet = Import::Sheet.read(upload("Export.TXT", "\xFF\xFE".b + text.b))

    assert_equal [ [ "Date", "Name", "Amount" ], [ "2024-10-01", "Café", "5.50" ] ], [ sheet.headers, sheet.rows.sole.cells ]
  end

  test "title rows above the header are skipped and a blank header is named after its column" do
    sheet = Import::Sheet.read(upload("spending.csv", "My spending\n\nDate,,Amount\n2024-10-01,Coffee,5.50,extra\n"))

    assert_equal [ "Date", "Column B", "Amount", "Column D" ], sheet.headers
    assert_equal [ [ 4, [ "2024-10-01", "Coffee", "5.50", "extra" ] ] ], sheet.rows.map { |row| [ row.number, row.cells ] }
  end

  test "an xlsx keeps its typed cells and reads amounts from the digits Excel stored" do
    rows = Import::Sheet.read(import_file("history.xlsx")).rows

    assert_equal [ Date.new(2023, 12, 27), "Whole Foods", "Groceries", BigDecimal("1234.5599999999999"), false ], rows[1].cells
    assert_equal [ Date, String, String, BigDecimal, FalseClass ], rows[1].cells.map(&:class)
    assert_equal Date.new(2024, 1, 5), rows[5].cells.first
    assert_equal [ nil, "Total", nil, BigDecimal("65.9") ], rows.last.cells
  end

  test "xlsx tabs that share a header, case and spacing aside, combine and the tab that doesn't is named" do
    sheet = Import::Sheet.read(import_file("history.xlsx"))

    assert_equal [ "Date", "Item", "Category", "Amount", "Excluded" ], sheet.headers
    assert_equal [ [ "2023", "2024" ], [ "Summary" ] ], [ sheet.tabs, sheet.skipped_tabs ]
    assert_equal [ [ "2023", 4 ], [ "2023", 5 ], [ "2023", 6 ], [ "2024", 2 ], [ "2024", 3 ], [ "2024", 4 ], [ "2024", 5 ] ],
      sheet.rows.map { |row| [ row.tab, row.number ] }
  end

  test "the stored form brings back dates as dates and numbers as numbers" do
    sheet = Import::Sheet.read(import_file("history.xlsx"))
    stored = Import::Sheet.load(Import::Sheet.dump(sheet))

    assert_equal sheet.rows.map(&:cells), stored.rows.map(&:cells)
    assert_equal [ Date, String, String, BigDecimal, FalseClass ], stored.rows.first.cells.map(&:class)
    assert_equal [ sheet.headers, [ "2023", "2024" ], [ "Summary" ], "2023", 4 ],
      [ stored.headers, stored.tabs, stored.skipped_tabs, stored.rows.first.tab, stored.rows.first.number ]
    assert_nil Import::Sheet.load(nil)
  end

  test "the preview is the first eight rows and a column is every cell under one header" do
    sheet = Import::Sheet.read(import_file("personal.csv"))

    assert_equal [ 2, 3, 4, 5, 6, 8, 9, 10 ], sheet.preview.map(&:number)
    assert_equal [ "Coffee", "Coffee", "Coffee", "Groceries", "Travel", "groceries", "Coffee", "Housing", "Groceries", "Fun", "Fun", "food", nil ],
      sheet.column(2)
  end

  test "a cell reads as text the way a spreadsheet shows it" do
    assert_equal [ "12", "12.5", "2024-10-02", "Coffee", "true", nil ],
      [ BigDecimal("12"), BigDecimal("12.50"), Date.new(2024, 10, 2), "Coffee", true, nil ].map { |cell| Import::Sheet.text(cell) }
  end

  test "files it can't use say why" do
    assert_unreadable "Choose an Excel (.xlsx) or CSV file.", upload("receipt.pdf", "%PDF-1.4")
    assert_unreadable "Save it as .xlsx or CSV first.", upload("old.xls", "anything")
    assert_unreadable "Save it as .xlsx or CSV first.", upload("history.numbers", "anything")
    assert_unreadable "Choose an Excel (.xlsx) or CSV file.", upload("renamed.xlsx", "Date,Amount\n2024-10-01,5\n")
    assert_unreadable "Couldn't find a header row with column names.", upload("numbers.csv", "1,2\n3,4\n")
    assert_unreadable "There are no rows under the header.", upload("empty.csv", "Date,Name,Amount\n\n")
  end

  test "a damaged workbook says it isn't a spreadsheet" do
    parts = Zip::File.open(file_fixture("imports/history.xlsx")) { |zip| zip.entries.to_h { |entry| [ entry.name, entry.get_input_stream.read ] } }

    assert_unreadable "Choose an Excel (.xlsx) or CSV file.", upload("parts.xlsx", xlsx(parts.except("xl/_rels/workbook.xml.rels")))
    assert_unreadable "Choose an Excel (.xlsx) or CSV file.", upload("styles.xlsx", xlsx(parts.except("xl/styles.xml")))
    capture_subprocess_io do
      assert_unreadable "Choose an Excel (.xlsx) or CSV file.", upload("cut.xlsx", xlsx(parts.merge("xl/worksheets/sheet1.xml" => "<worksheet><sheetData><row r=\"1\">")))
    end
    assert_unreadable "Choose an Excel (.xlsx) or CSV file.", upload("half.xlsx", file_fixture("imports/history.xlsx").binread.first(1_000))
  end

  test "a workbook with macros asks for a plain copy" do
    assert_unreadable "Save it as .xlsx or CSV first.", upload("macros.xlsx", xlsx("xl/workbook.xml" => "<workbook/>", "xl/_rels/workbook.xml.rels" => "<Relationships/>", "xl/vbaProject.bin" => "macros"))
  end

  test "files too big to read are refused before they are read" do
    assert_unreadable "That file is over 10 MB. Split it or save fewer tabs.", upload("big.csv", "a" * (10.megabytes + 1))
    assert_unreadable "That file has over 50,000 rows. Split it into smaller files.", upload("long.csv", "Date,Amount\n" + "2024-10-01,5\n" * 50_000)
    assert_unreadable "That file has over 40 columns. Delete the ones you don't need.", upload("wide.csv", ("A".."AO").to_a.join(",") + "\n")
  end

  test "a zip that would unpack into too much is refused before it is unpacked" do
    many_parts = (1..201).to_h { |n| [ "xl/part#{n}.xml", "<x/>" ] }.merge("xl/workbook.xml" => "<workbook/>")
    bomb = { "xl/workbook.xml" => "<workbook/>", "xl/worksheets/sheet1.xml" => "\0" * (100.megabytes + 1) }

    assert_unreadable "That file is over 10 MB. Split it or save fewer tabs.", upload("many.xlsx", xlsx(many_parts))
    assert_unreadable "That file is over 10 MB. Split it or save fewer tabs.", upload("bomb.xlsx", xlsx(bomb))
  end

  test "a row of exactly the limits still reads" do
    sheet = Import::Sheet.read(upload("edge.csv", ("A".."AN").to_a.join(",") + "\n" + "x,y\n" * 49_999))

    assert_equal [ 40, 49_999 ], [ sheet.headers.size, sheet.rows.size ]
  end

  private
    def assert_unreadable(message, file)
      error = assert_raises(Import::Sheet::Unreadable) { Import::Sheet.read(file) }
      assert_equal message, error.message
    end
end
