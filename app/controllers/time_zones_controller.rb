class TimeZonesController < ApplicationController
  def update
    Current.user.adopt_time_zone(params.expect(:time_zone))
    head :no_content
  end
end
