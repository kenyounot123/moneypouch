class Transaction::Categorization < Data.define(:category, :transfer)
  def self.from(category:, transfer:, categories:, money_in:)
    name = category.to_s.squish

    if ActiveModel::Type::Boolean.new.cast(transfer)
      self.transfer
    elsif name.empty?
      none
    else
      new(category: categories.named(name).first || categories.build(name:, income: money_in))
    end
  end

  def self.transfer
    new(category: nil, transfer: true)
  end

  def self.none
    new(category: nil)
  end

  def initialize(category:, transfer: false)
    if category && transfer
      raise ArgumentError, "a transfer has no category"
    end

    super
  end

  def transfer?
    transfer
  end

  def none?
    category.nil? && !transfer
  end
end
