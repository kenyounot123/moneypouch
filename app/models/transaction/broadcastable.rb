module Transaction::Broadcastable
  extend ActiveSupport::Concern

  included do
    # Not broadcasts_refreshes_to: its debounced job reaches other screens a second or more after the change.
    after_commit -> { broadcast_refresh_to(user, :transactions) }
  end

  class_methods do
    def broadcasting_once_for(user)
      suppressing_turbo_broadcasts { yield }
      Turbo::StreamsChannel.broadcast_refresh_to(user, :transactions)
    end
  end
end
