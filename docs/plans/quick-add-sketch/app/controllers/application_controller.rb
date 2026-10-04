class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes

  # P5. Every request runs in the browser's zone, so Date.current IS the user's
  # today everywhere (Transaction#stashed_on, Month.current, Spending). No
  # Current.today attribute to thread through: one source, the Rails default.
  around_action :use_browser_time_zone

  private

  # The cookie is written by time_zone_controller.js (IANA name, e.g.
  # "America/Los_Angeles"). Unknown or missing -> UTC. Validated here, the boundary.
  def use_browser_time_zone(&)
    Time.use_zone(ActiveSupport::TimeZone[cookies[:time_zone].to_s] || "UTC", &)
  end
end
