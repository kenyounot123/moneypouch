# Writes are symmetric so undo is symmetric. The server declares each inverse,
# because only the server knows the exact previous state:
#
#   action                    model call             inverse it declares
#   POST   /transactions      new.stash(line)        DELETE /transactions/:id
#   PATCH  /transactions/:id  find.stash(line)       PATCH  /transactions/:id line=<previous line>
#   DELETE /transactions/:id  find.discard           POST   /transactions/:id/restoration
#   POST   .../restoration    find.restore           (none)
#
# A request carrying `undo=1` is a replay of an inverse, and its response
# declares no new inverse, so pressing u three times undoes three changes and
# never redoes. Every success renders transactions/change.turbo_stream.erb; the
# client then morph-refreshes the page (support/write.js). Rows are never streamed.
class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ update destroy ]

  # P7. GET /transactions?month=2026-08
  def index
    @month = Month.parse(params[:month])
    @days = Current.user.transactions.during(@month).by_day.eager_load(:category).group_by(&:occurred_on)
  end

  # P5. Idempotent on idempotency_key: triple Enter, a retry after a lost
  # response, or a resubmit after the server came back all converge to one row.
  # The bar mints a fresh key per line and keeps it until that line saves.
  def create
    @transaction = Current.user.transactions.find_or_initialize_by(idempotency_key: params.expect(:idempotency_key))
    raise NotImplementedError
    # return render_change(inverse: inverse_of_create, status: :ok) if @transaction.persisted?
    # if @transaction.stash(params.expect(:line)) then render_change(inverse: inverse_of_create, status: :created)
    # else render_rejection
  end

  # P9. Edit through the bar, and undo of an edit.
  def update
    previous_line = @transaction.editable_line
    raise NotImplementedError
    # if @transaction.stash(params.expect(:line))
    #   render_change(inverse: { method: :patch, url: transaction_path(@transaction), line: previous_line })
    # else render_rejection
  end

  # P9. Discard, never destroy.
  def destroy
    @transaction.discard
    render_change(inverse: { method: :post, url: transaction_restoration_path(@transaction) })
  end

  private

  # Kept only (User#transactions). A replayed DELETE or a PATCH on a discarded
  # row is a 404, which support/write.js reports as "Already undone".
  def set_transaction
    @transaction = Current.user.transactions.find(params.expect(:id))
  end

  def inverse_of_create = { method: :delete, url: transaction_path(@transaction) }

  # The one success response for every write, restorations included.
  def render_change(inverse:, status: :ok)
    raise NotImplementedError
    # render "transactions/change", formats: :turbo_stream, status:,
    #   locals: { inverse: (inverse unless params[:undo]), toast: <copy for this action> }
  end

  # The invalid line keeps its text (the bar owns it); only the pills change.
  def render_rejection
    raise NotImplementedError
    # render turbo_stream: turbo_stream.update("draft", partial: "drafts/error",
    #   locals: { message: @transaction.errors[:base].first }), status: :unprocessable_content
  end
end
