require "test_helper"

class DraftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "asks for an amount when the line has none" do
    get draft_url(line: "coffee")

    assert_response :success
    assert_select "turbo-frame#draft", text: /Type an amount, like 5.50/
  end

  test "shows the row the line would save" do
    get draft_url(line: "Blue Bottle +2400 yesterday")

    assert_select "turbo-frame#draft [data-inferred-category=Food]", text: /Blue Bottle\s+Food\s+· Yesterday\s+\+\$2,400.00\s+Money in/
  end

  test "marks a category the user has not saved" do
    get draft_url(line: "lunch 12 #brandnew")

    assert_select "turbo-frame#draft", text: /brandnew \(new\)/
    assert_select "[data-inferred-category]", count: 0
  end

  test "never shows another user's categories" do
    sign_in_as(users(:two))
    get draft_url(line: "Blue Bottle 6")

    assert_select "turbo-frame#draft", text: /Uncategorized/
    assert_select "turbo-frame#draft", text: /Food/, count: 0
  end

  test "reads today in the browser's time zone" do
    travel_to Time.utc(2026, 10, 4, 12) do
      cookies[:time_zone] = "Pacific/Kiritimati"
      get draft_url(line: "tea 3 oct 4")
      assert_select "turbo-frame#draft", text: /Yesterday/

      cookies[:time_zone] = "Not/AZone"
      get draft_url(line: "tea 3 oct 4")
      assert_select "turbo-frame#draft", text: /Today/
    end
  end

  test "shows only the legend for an empty line" do
    get draft_url(line: "")

    assert_select "turbo-frame#draft > div", count: 1
    assert_select "turbo-frame#draft", text: /5.50\s+amount\s+@\s+date\s+#\s+category/
  end

  test "offers a used name only when asked" do
    get draft_url(line: "blu", complete: "1")
    assert_select "[data-line='blu'][data-completion='Blue Bottle'][data-inferred-category=Food]", text: /Blue Bottle\s+Tab\s+Food/
    assert_select "[data-completion] .text-tertiary", text: "e Bottle"

    get draft_url(line: "Blu")
    assert_select "[data-completion]", count: 0
  end
end
