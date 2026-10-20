require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "the Import page offers a drop zone that uploads as soon as a file is chosen" do
    get new_import_url

    assert_response :success
    assert_select "h1", text: "Import"
    assert_select "main p", text: "Import your previous expense history that you already keep in a file."
    assert_select "form[action=?] label", imports_path, text: /Drop a file here\s+Reading the file…\s+Excel \(.xlsx\) or CSV\s+Choose file/
    assert_select "input[type=file][name='import[file]'][onchange='this.form.requestSubmit()']"
    assert_select "main p", text: "One row per transaction, with at least a date and an amount. Names, categories and notes come along if you have them."
    assert_select "main button", text: "Undo", count: 0
    assert_select "aside a[aria-current=page][href=?]", new_import_path, text: "Import"
    assert_select "ol[aria-label='Import steps'] li[aria-current=step]", text: "1 File"
  end

  test "an upload reads the file and opens the Columns step" do
    post imports_url, params: { import: { file: import_file("personal.csv") } }

    import = @user.imports.sole
    assert_redirected_to edit_import_columns_url(import)
    assert_equal [ "personal.csv", true ], [ import.filename, import.draft? ]
  end

  test "a file it can't read stays on the Import page, says why, and keeps the draft in progress" do
    draft = @user.start_import(import_file("personal.csv"))

    post imports_url, params: { import: { file: upload("receipt.pdf", "%PDF-1.4") } }

    assert_response :unprocessable_entity
    assert_select "label span.text-danger", text: "Choose an Excel (.xlsx) or CSV file."
    assert_select "input[type=file][aria-invalid=true]"
    assert_equal [ draft ], @user.imports.to_a
  end

  test "the Import page shows only the latest import, with an Undo that asks first" do
    travel_to Time.utc(2026, 10, 2, 12) do
      @user.start_import(import_file("history.xlsx")).complete
    end
    travel_to Time.utc(2026, 10, 15, 12) do
      @user.start_import(import_file("personal.csv")).complete
    end

    get new_import_url

    assert_select "main p", text: "Imported 11 transactions from personal.csv on Oct 15."
    assert_select "main p", text: /history.xlsx/, count: 0
    assert_select "form[action=?][data-turbo-confirm=?] button", import_path(@user.latest_import), "Remove the 11 transactions from personal.csv?", text: "Undo"
  end

  test "Undo removes the import's rows, and pressing it again still lands on the Import page" do
    import = @user.start_import(import_file("personal.csv"))
    import.complete

    assert_difference -> { Transaction.count }, -11 do
      delete import_url(import)
    end
    assert_redirected_to new_import_url

    delete import_url(import)
    assert_redirected_to new_import_url
  end

  test "Undo on another user's import leaves it alone" do
    theirs = users(:two).start_import(import_file("personal.csv"))
    theirs.complete

    assert_no_difference -> { Transaction.count } do
      delete import_url(theirs)
    end
    assert_redirected_to new_import_url
    assert theirs.reload.completed?
  end
end
