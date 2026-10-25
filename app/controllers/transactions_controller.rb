class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit destroy ]

  def index
    @query = Transaction::Query.parse(params.permit(:q)[:q], user: Current.user, today: Date.current)
    @month = @query.month || Period.month(params[:month], today: Date.current)
    @this_month = Period.new("month", today: Date.current)
    @sort = Transaction::Sort.parse(params[:sort], params[:direction])
    @listing = Transaction::Listing.new(Current.user.transactions, period: @month, query: @query, before:, sort: @sort, number: page_number)
    @import = Current.user.imports.completed.find_by(id: flash[:import_id])
    @categories = Current.user.categories.alphabetically
    @bank_accounts = Current.user.bank_accounts.order(:name)
    @category_counts = Current.user.transactions.group(:category_id).count
    keep_categorized_for_later_page
  end

  def edit
    @categories = Current.user.categories.alphabetically
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

  def destroy
    @transaction.discard
    redirect_back_or_to root_path, flash: { shorthand: @transaction.shorthand }, status: :see_other
  end

  private
    def set_transaction
      @transaction = Current.user.transactions.find(params.expect(:id))
    end

    def before
      Date.iso8601(params[:before].to_s)
    rescue Date::Error
      nil
    end

    def page_number
      [ params[:page].to_i, 1 ].max
    end

    def keep_categorized_for_later_page
      id = flash[:categorized_id]

      if id && @listing.page.next_params && @listing.transactions.none? { |transaction| transaction.id == id }
        flash.keep(:categorized_id)
      end
    end
end
