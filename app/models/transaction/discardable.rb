module Transaction::Discardable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(discarded_at: nil) }
  end

  def discard
    update!(discarded_at: Time.current)
  end
end
