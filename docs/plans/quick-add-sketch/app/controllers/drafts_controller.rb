# P5. GET /draft?line=coffee+5.50[&transaction_id=42]
# Renders the pills (or the first error) for how the line would save. Served
# inside <turbo-frame id="draft">: the bar sets the frame's src on each input,
# and Turbo's FrameController cancels the in-flight request, so only the latest
# line's response ever paints (checked in turbo-rails 2.0.23).
# In edit mode the bar sends transaction_id so the preview reads the line against
# the same anchor date, and the same inference exclusion, the PATCH will.
class DraftsController < ApplicationController
  def show
    transaction = Current.user.transactions.find_by(id: params[:transaction_id]) || Current.user.transactions.new
    @draft = transaction.draft(params[:line].to_s)
  end
end
