require "test_helper"

class VouchersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "asks for an amount when the shorthand has none" do
    get voucher_url(shorthand: "coffee")

    assert_response :success
    assert_select "turbo-frame#voucher", text: /Type an amount, like 5.50/
  end

  test "shows the row the shorthand would save" do
    get voucher_url(shorthand: "Blue Bottle +2400 yesterday")

    assert_select "turbo-frame#voucher [data-inferred-category=Food]", text: /Blue Bottle\s+Food\s+· Yesterday\s+\+\$2,400.00\s+Money in/
  end

  test "marks a category the user has not saved" do
    get voucher_url(shorthand: "lunch 12 #brandnew")

    assert_select "turbo-frame#voucher", text: /New category\s+brandnew/
    assert_select "[data-inferred-category]", count: 0
  end

  test "never shows another user's categories" do
    sign_in_as(users(:two))
    get voucher_url(shorthand: "Blue Bottle 6")

    assert_select "turbo-frame#voucher", text: /Uncategorized/
    assert_select "turbo-frame#voucher", text: /Food/, count: 0
  end

  test "reads today in the browser's time zone" do
    travel_to Time.utc(2026, 10, 4, 12) do
      cookies[:time_zone] = "Pacific/Kiritimati"
      get voucher_url(shorthand: "tea 3 oct 4")
      assert_select "turbo-frame#voucher", text: /Yesterday/

      cookies[:time_zone] = "Not/AZone"
      get voucher_url(shorthand: "tea 3 oct 4")
      assert_select "turbo-frame#voucher", text: /Today/
    end
  end

  test "shows only the legend for empty shorthand" do
    get voucher_url(shorthand: "")

    assert_select "turbo-frame#voucher > div", count: 1
    assert_select "turbo-frame#voucher", text: /5.50\s+amount\s+@\s+date\s+#\s+category/
  end

  test "offers a used name only when asked" do
    get voucher_url(shorthand: "blu", complete: "1")
    assert_select "[data-shorthand='blu'][data-completion='Blue Bottle'][data-inferred-category=Food]", text: /Blue Bottle\s+Tab\s+Food/
    assert_select "[data-completion] .text-tertiary", text: "e Bottle"

    get voucher_url(shorthand: "Blu")
    assert_select "[data-completion]", count: 0
  end

  test "infers the category for shorthand ending in a bare hash" do
    get voucher_url(shorthand: "Blue Bottle 6.40 #")

    assert_select "[data-inferred-category=Food]", text: /Blue Bottle\s+Food/
  end
end
