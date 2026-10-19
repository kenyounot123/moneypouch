require "test_helper"

class Imports::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "the Columns step puts each column's guess above the file's first rows" do
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_columns_url(import)

    assert_response :success
    assert_select "main p", text: "personal.csv"
    assert_select "main p", text: "13 rows"
    assert_select "main h2", text: "What's in each column?"
    assert_select "main p", text: "We guessed from your headers. Fix any we got wrong."
    assert_select "main p", text: "personal.csv · 13 rows. Fix any column we guessed wrong.", count: 0
    assert_equal %w[ date name category amount excluded note ], css_select("select[name='import[columns][]'] option[selected]").map { |option| option["value"] }
    assert_equal [ "Date", "Item", "Category", "Amount", "Excluded", "Note" ], css_select("thead tr:nth-child(2) th").map(&:text)
    assert_equal [ "2024-10-01", "Blue Bottle", "Coffee", "5.50", "", "" ], css_select("tbody tr:first-child td").map(&:text)
    assert_select "tbody tr", 8
    assert_select "form p", text: "5 more rows"
    assert_select "input[type=radio][name='import[positive_amounts]'][value=spent][checked]"
    assert_select "form p", text: "Rows with no date, like totals, are left out.", count: 0
    assert_select "form[action=?] button", import_path(import), text: "Cancel"
    assert_select "aside a[aria-current=page]", text: "Import"
  end

  test "the field list shows which fields the file has and where each comes from" do
    import = @user.start_import(import_file("personal.csv"))

    get edit_import_columns_url(import)

    assert_equal [ "Needed", "If your file has them" ], css_select("form ul").map { |list| list.parent.at_css("p").text }
    assert_equal [ "Date", "Amount", "Name", "Spent or income", "Category", "Transfer", "Excluded from totals", "Note" ], css_select("form li p:first-child").map(&:text)
    assert_equal [ "from Date", "from Amount", "from Item", "Not in this file", "from Category", "Not in this file", "from Excluded", "from Note" ], css_select("form li [data-columns-target=source]").map(&:text)
    assert_select "li[data-kind=date][data-matched]"
    assert_select "li[data-kind=transfer]:not([data-matched])"
    assert_select "li[data-kind=name] p", text: "What it was, like a store."
    assert_select "select[aria-label='Item column'][data-header=Item][data-columns-target=select]"
  end

  test "a workbook says how many tabs it read and names the one it skipped" do
    import = @user.start_import(import_file("history.xlsx"))

    get edit_import_columns_url(import)

    assert_select "main p", text: "history.xlsx"
    assert_select "main p", text: "7 rows from 2 tabs"
    assert_select "main p", text: "Skipped the Summary tab, which has different columns."
    assert_equal [ "2023-12-27", "Whole Foods", "Groceries", "1234.56", "false" ], css_select("tbody tr:nth-child(2) td").map(&:text)
  end

  test "a bank export's guess reads positive amounts as income" do
    import = @user.start_import(import_file("bank.csv"))

    get edit_import_columns_url(import)

    assert_select "input[type=radio][name='import[positive_amounts]'][value=income][checked]"
    assert_select "select[aria-label='Balance column'] option[selected][value=skip]"
  end

  test "Next saves what each column is and opens Categories" do
    import = @user.start_import(import_file("personal.csv"))

    patch import_columns_url(import), params: { import: { columns: %w[ date name category amount skip note ], positive_amounts: "income" } }

    assert_redirected_to edit_import_categories_url(import)
    assert_equal Import::Columns.new(kinds: %w[ date name category amount skip note ], positive_amounts: "income"), import.reload.columns
  end

  test "columns that can't be read stay on the step and say what to fix" do
    import = @user.start_import(import_file("personal.csv"))

    patch import_columns_url(import), params: { import: { columns: %w[ skip name name amount skip note ], positive_amounts: "spent" } }

    assert_response :unprocessable_entity
    assert_equal [ "Choose a Date column.", "Only one column can be Name." ], css_select("[role=alert] p").map(&:text)
    assert_equal %w[ skip name name amount skip note ], css_select("select option[selected]").map { |option| option["value"] }
    assert_equal %w[ date name category amount excluded note ], import.reload.columns.kinds
  end

  test "another user's import isn't found" do
    theirs = users(:two).start_import(import_file("personal.csv"))

    get edit_import_columns_url(theirs)
    assert_response :not_found

    patch import_columns_url(theirs), params: { import: { columns: %w[ date ], positive_amounts: "spent" } }
    assert_response :not_found
  end

  test "a finished import's step lands on the Import page" do
    import = @user.start_import(import_file("personal.csv"))
    import.complete

    get edit_import_columns_url(import)

    assert_redirected_to new_import_url
  end
end
