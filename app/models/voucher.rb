class Voucher
  attr_reader :shorthand, :calendar

  delegate :name, :category_word, :occurred_on, :tokens, :errors, to: :parts

  def initialize(shorthand, user:, today:, complete: false, calendar: nil)
    @shorthand = shorthand.to_s
    @user = user
    @today = today
    @complete = complete
    @calendar = calendar.to_s.presence
  end

  def completion
    return @completion if defined?(@completion)

    @completion = (@user.transactions.name_starting_with(typed) if @complete && completable?)
  end

  def category
    return @category if defined?(@category)

    @category = resolve_category(completion || name)
  end

  # An unsigned amount in an income category is money in, as if it were typed with a +.
  def amount_in_cents
    if parts.amount_in_cents && !parts.signed && category&.income?
      parts.amount_in_cents.abs
    else
      parts.amount_in_cents
    end
  end

  def category_name
    category&.name
  end

  def aim
    if calendar
      Transaction::Shorthand.aim(calendar, today: @today)
    end
  end

  def dated?
    parts.dated
  end

  def inferred?
    category.present? && category_word.nil?
  end

  def valid?
    errors.empty?
  end

  def money_in?
    amount_in_cents.to_i.positive?
  end

  def attributes
    { name:, amount_in_cents:, occurred_on:, category:, shorthand: }
  end

  private
    def last_category_for(name)
      if name.present?
        @user.transactions.last_category_for(name)
      end
    end

    def parts
      @parts ||= Transaction::Shorthand.read(shorthand, today: @today)
    end

    def typed_money_in?
      parts.amount_in_cents.to_i.positive?
    end

    def typed
      shorthand.lstrip
    end

    def completable?
      typed.gsub(/\s/, "").length >= 2 && !typed.match?(/[\d#@$+]/)
    end

    def resolve_category(name)
      if category_word
        @user.categories.named(category_word).first || Category.new(user: @user, name: category_word, income: typed_money_in?)
      else
        last_category_for(name) || (@user.income_category if typed_money_in?)
      end
    end
end
