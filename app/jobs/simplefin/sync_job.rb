class Simplefin::SyncJob < ApplicationJob
  def perform(sync)
    sync.run_now
  end
end
