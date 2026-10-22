require "test_helper"

class TimeZoneTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "a page read leaves the saved time zone alone" do
    cookies[:time_zone] = "Europe/Berlin"

    get settings_url

    assert_equal "UTC", users(:one).reload.time_zone
    assert_select "html[data-time-zone-saved-value=UTC][data-time-zone-url-value=?]", time_zone_path
  end

  test "the browser's time zone is saved for jobs that run without a request" do
    patch time_zone_url, params: { time_zone: "Europe/Berlin" }

    assert_response :no_content
    assert_equal "Europe/Berlin", users(:one).reload.time_zone
  end

  test "a time zone that can't be read leaves the saved one alone" do
    users(:one).update!(time_zone: "Asia/Tokyo")

    patch time_zone_url, params: { time_zone: "Not/AZone" }

    assert_equal "Asia/Tokyo", users(:one).reload.time_zone
  end
end
