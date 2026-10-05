class Voucher
  attr_reader :shorthand

  delegate :name, :amount_in_cents, :category_word, :occurred_on, :errors, to: :parts

  def initialize(shorthand, user:, today:, complete: false, editing: nil)
    @shorthand = shorthand.to_s
    @user = user
    @today = today
    @complete = complete
    @editing = editing
  end

  def completion
    return @completion if defined?(@completion)

    @completion = (@user.transactions.name_starting_with(typed) if @complete && completable?)
  end

  def category
    return @category if defined?(@category)

    @category = resolve_category(completion || name)
  end

  def category_name
    category&.name
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
    def parts
      @parts ||= Transaction::Shorthand.read(shorthand, today: @today)
    end

    def typed
      shorthand.lstrip
    end

    def completable?
      typed.gsub(/\s/, "").length >= 2 && !typed.match?(/[\d#@$+]/)
    end

    def resolve_category(name)
      if category_word
        @user.categories.named(category_word).first || Category.new(user: @user, name: category_word)
      elsif name.present?
        @user.transactions.excluding(@editing).last_category_for(name)
      end
    end
end
