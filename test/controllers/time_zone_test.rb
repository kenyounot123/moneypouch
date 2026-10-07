require "test_helper"

class TimeZoneTest < ActionDispatch::IntegrationTest
  test "the browser's time zone is saved for jobs that run without a request" do
    sign_in_as(users(:one))
    cookies[:time_zone] = "Europe/Berlin"

    get settings_url

    assert_equal "Europe/Berlin", users(:one).reload.time_zone
  end

  test "a time zone the cookie cannot name leaves the saved one alone" do
    users(:one).update!(time_zone: "Asia/Tokyo")
    sign_in_as(users(:one))
    cookies[:time_zone] = "Not/AZone"

    get settings_url

    assert_equal "Asia/Tokyo", users(:one).reload.time_zone
  end
end
