class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit destroy ]

  helper_method :filters

  def index
    @month = Month.new(params[:month], today: Date.current)
    @listing = Transaction::Listing.new(Current.user, month: @month, filters:, before:)
    @voucher = Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
    @added = Current.user.transactions.find_by(id: flash[:added_id])
    @import = Current.user.imports.completed.find_by(id: flash[:import_id])
    @categories = Current.user.categories.alphabetically
    @bank_accounts = Current.user.bank_accounts.order(:name)
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

    def filters
      params.permit(:query, :account, :category, :needs).to_h.compact_blank.symbolize_keys
    end

    def before
      Date.iso8601(params[:before].to_s)
    rescue Date::Error
      nil
    end

    def keep_categorized_for_later_page
      id = flash[:categorized_id]

      if id && @listing.page.next_before && @listing.transactions.none? { |transaction| transaction.id == id }
        flash.keep(:categorized_id)
      end
    end
end
