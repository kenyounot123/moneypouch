class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[ edit update destroy ]

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
    @fields = { name: @transaction.name, amount: editable_amount(@transaction.amount_in_cents), occurred_on: @transaction.occurred_on.iso8601, note: @transaction.note }
  end

  def update
    @fields = params.expect(transaction: %i[ name amount occurred_on note ])
    amount_in_cents = Transaction::Shorthand.amount_in_cents(@fields[:amount])
    occurred_on = iso_date(@fields[:occurred_on])

    @transaction.assign_attributes(name: @fields[:name].to_s.strip, note: @fields[:note].to_s,
      amount_in_cents: amount_in_cents || @transaction.amount_in_cents, occurred_on: occurred_on || @transaction.occurred_on)
    @transaction.valid?
    @errors = [ *@transaction.errors[:name], (Transaction::Shorthand::MISSING_AMOUNT unless amount_in_cents), (Transaction::Shorthand::MISSING_DATE unless occurred_on) ].compact

    if @errors.empty? && @transaction.save
      redirect_back_or_to root_path, status: :see_other
    else
      @transaction.restore_attributes
      @categories = Current.user.categories.alphabetically
      render turbo_stream: turbo_stream.replace("sheet", template: "transactions/edit", formats: :html), status: :unprocessable_entity
    end
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
    def editable_amount(cents)
      format("%s%d.%02d", ("+" if cents.positive?), cents.abs / 100, cents.abs % 100)
    end

    def set_transaction
      @transaction = Current.user.transactions.find(params.expect(:id))
    end

    def before
      iso_date(params[:before])
    end

    def iso_date(text)
      Date.iso8601(text.to_s)
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
