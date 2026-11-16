module Transaction::Broadcastable
  extend ActiveSupport::Concern

  included do
    after_commit :refresh_other_screens_at_once
  end

  class_methods do
    def broadcasting_once_for(user)
      suppressing_turbo_broadcasts { yield }.tap do
        Turbo::StreamsChannel.broadcast_refresh_to(user, :transactions)
      end
    end
  end

  private
    def refresh_other_screens_at_once
      broadcast_refresh_to(user, :transactions)
    end
end
