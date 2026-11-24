require "test_helper"

class PossibleDuplicatesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    @user = users(:one)
    sign_in_as(@user)
    @access = connect_simplefin
  end

  test "a purchase imported first and synced from the bank later stops counting twice once answered" do
    import "october.csv", "Date,Name,Category,Amount\n2026-10-06,Whole Foods,Food,48.20\n"
    sync bank_row("groceries", -4_820, 1, "WHOLEFDS MKT")

    get simplefin_review_url
    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Possible duplicates\s+1/
    assert_select "main", text: /Whole Foods\s+Oct 6 · From october\.csv\s+\$48\.20/
    assert_select "main", text: /WHOLEFDS MKT\s+Oct 1 · SimpleFIN Checking\s+\$48\.20/

    assert_difference -> { @user.transactions.spent }, -4_820 do
      press "Same transaction"
    end
    assert_equal [ [ "WHOLEFDS MKT", "Food" ] ], kept(-4_820)
  end

  test "a purchase synced from the bank first and imported later stops counting twice once answered" do
    sync bank_row("groceries", -4_820, 6, "WHOLEFDS MKT")
    import "october.csv", "Date,Name,Category,Amount\n2026-10-06,Whole Foods,Food,48.20\n"

    get simplefin_review_url
    assert_select "nav[aria-label=Lists] a[aria-current=true]", text: /Possible duplicates\s+1/

    assert_difference -> { @user.transactions.spent }, -4_820 do
      press "Same transaction"
    end
    assert_equal [ [ "WHOLEFDS MKT", "Food" ] ], kept(-4_820)
  end

  test "an imported row that adds up two bank rows keeps both bank rows once answered" do
    import "october.csv", "Date,Name,Category,Amount\n2026-10-06,Groceries,Food,65.57\n"
    sync bank_row("first", -4_820, 5, "WHOLEFDS MKT"), bank_row("second", -1_737, 6, "TRADER JOES")

    get simplefin_review_url
    assert_select "main", text: /Adds up to \$65\.57/

    assert_difference -> { @user.transactions.spent }, -6_557 do
      press "Same transaction"
    end
    assert_equal [ [], [ [ "WHOLEFDS MKT", "Food" ] ], [ [ "TRADER JOES", "Food" ] ] ], [ kept(-6_557), kept(-4_820), kept(-1_737) ]
  end

  private
    def import(filename, content)
      post imports_url, params: { import: { file: upload(filename, content) } }
      draft = @user.imports.drafts.sole
      patch import_columns_url(draft), params: { import: { columns: draft.columns.kinds, positive_amounts: "spent" } }
      post import_transactions_url(draft)
    end

    def sync(*bank_rows)
      report = simplefin_report
      demo_account(report, "Demo Savings")["transactions"] = []
      demo_account(report, "Demo Checking")["transactions"] = bank_rows
      activate(@access, report:)
    end

    def bank_row(id, cents, day, name)
      { "id" => id, "posted" => Time.utc(2026, 10, day, 18).to_i, "amount" => format("%.2f", cents / 100.0), "description" => name }
    end

    def press(label)
      form = css_select("main form").find { |candidate| candidate.at_css("button")&.text&.squish == label }
      assert form, "no #{label} button"
      post form["action"], params: form.css("input[type=hidden]").map { |input| URI.encode_www_form([ [ input["name"], input["value"] ] ]) }.join("&")
      assert_response :see_other
    end

    def kept(amount_in_cents)
      @user.transactions.where(amount_in_cents:).order(:id).map { |transaction| [ transaction.name, transaction.category&.name ] }
    end
end
