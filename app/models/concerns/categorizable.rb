module Categorizable
  extend ActiveSupport::Concern

  included do
    belongs_to :category, optional: true
  end

  def categorization
    Transaction::Categorization.new(category:, transfer:)
  end

  def categorization=(categorization)
    self.category = categorization.category
    self.transfer = categorization.transfer?
  end
end
