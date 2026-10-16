class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit update destroy ]

  helper_method :filters

  def index
    transactions = Current.user.transactions
    @month = Month.new(params[:month], today: Date.current)
    @voucher = Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
    @added = transactions.find_by(id: flash[:added_id])
    @import = Current.user.imports.completed.find_by(id: flash[:import_id])
    @categories = Current.user.categories.alphabetically
    @category_names = @categories.map(&:name)
    @bank_accounts = Current.user.bank_accounts.order(:name)

    narrowed = narrow(transactions.occurred_in(@month.range))
    shown = only_needing_category(narrowed)
    @needing_category_count = narrowed.needing_category.count
    @transactions = shown.listed.includes(bank_transaction: :bank_account)
    @spent = shown.spent
    @net = shown.net
    @income = shown.income
    @day_totals = shown.group(:occurred_on).sum(:amount_in_cents)
    @previous_count = only_needing_category(narrow(transactions.occurred_in(@month.previous.range))).count
    @earlier = transactions.occurred_in(...@month.range.begin).exists?
  end

  def edit
    @category_names = Current.user.categories.alphabetically.pluck(:name)
  end

  def create
    voucher = Voucher.new(params[:shorthand], user: Current.user, today: Date.current)

    if voucher.valid?
      transaction = Current.user.transactions.create_or_find_by!(idempotency_key: params[:idempotency_key]) do |row|
        row.assign_attributes(voucher.attributes)
      end
      redirect_back_or_to root_path, flash: { added_id: transaction.id }, status: :see_other
    else
      render turbo_stream: turbo_stream.replace("voucher", partial: "vouchers/voucher", locals: { voucher:, shake: true }),
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
    redirect_back_or_to root_path, flash: { shorthand: @transaction.shorthand }, status: :see_other
  end

  private
    def set_transaction
      @transaction = Current.user.transactions.find(params.expect(:id))
    end

    def transaction_params
      params.expect(transaction: [ :amount_in_cents, :currency ])
    end

    def filters
      params.permit(:query, :account, :category, :needs).to_h.compact_blank.symbolize_keys
    end

    def narrow(transactions)
      in_chosen_category(from_chosen_account(transactions.matching(filters[:query])))
    end

    def from_chosen_account(transactions)
      case filters[:account]
      when nil then transactions
      when "typed" then transactions.typed_in
      else transactions.from_bank_account(Current.user.bank_accounts.find(filters[:account]))
      end
    end

    def in_chosen_category(transactions)
      case filters[:category]
      when nil then transactions
      when "none" then transactions.uncategorized
      else transactions.in_category(Current.user.categories.find(filters[:category]))
      end
    end

    def only_needing_category(transactions)
      if filters[:needs]
        transactions.needing_category
      else
        transactions
      end
    end
end
