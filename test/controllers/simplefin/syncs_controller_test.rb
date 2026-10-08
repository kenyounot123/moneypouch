require "test_helper"

class Simplefin::SyncsControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    sign_in_as(users(:one))
    @access = activate(connect_simplefin)
  end

  test "Sync now queues a sync" do
    assert_enqueued_jobs 1, only: Simplefin::SyncJob do
      post simplefin_sync_url
    end

    assert_redirected_to settings_url
  end

  test "settings says it is syncing while a sync runs" do
    @access.sync_later

    get settings_url

    assert_select "button[disabled]", text: "Syncing…"
  end

  test "Sync now does nothing after 20 syncs in a day" do
    19.times { @access.syncs.create!(finished_at: Time.current) }

    assert_no_enqueued_jobs only: Simplefin::SyncJob do
      post simplefin_sync_url
    end
    get settings_url
    assert_select "button", text: "Sync now", count: 0
  end
end
