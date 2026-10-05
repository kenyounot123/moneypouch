class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ update destroy ]

  def index
    @transactions = Current.user.transactions.latest.includes(:category)
  end

  def create
    draft = Transaction::Draft.parse(params[:line], user: Current.user, today: Date.current)

    if draft.valid?
      transaction = Current.user.transactions.create_or_find_by!(idempotency_key: params[:idempotency_key]) do |row|
        row.assign_attributes(draft.attributes)
      end
      redirect_back_or_to root_path, flash: { added_id: transaction.id }, status: :see_other
    else
      render turbo_stream: turbo_stream.replace("draft", partial: "drafts/draft", locals: { draft:, shake: true }),
        status: :unprocessable_entity
    end
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: "Transaction was successfully updated.", status: :see_other
    else
      redirect_to transactions_path, alert: @transaction.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    @transaction.discard
    redirect_back_or_to root_path, flash: { line: @transaction.line }, status: :see_other
  end

  private
    def set_transaction
      @transaction = Current.user.transactions.find(params.expect(:id))
    end

    def transaction_params
      params.expect(transaction: [ :amount_in_cents, :currency ])
    end
end
