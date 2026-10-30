module User::Sandbox
  extend ActiveSupport::Concern

  LIFETIME = 24.hours
  SAMPLE_PURCHASES = 300

  included do
    scope :sandboxes, -> { where.not(expires_at: nil) }
    scope :lasting, -> { where(expires_at: nil) }
    scope :expired, -> { sandboxes.where(expires_at: ..Time.current) }
  end

  class_methods do
    def create_sandbox
      transaction do
        create!(username: "visitor-#{SecureRandom.hex(6)}", password: SecureRandom.base58(32), expires_at: LIFETIME.from_now).tap do |user|
          user.add_sample_transactions(SAMPLE_PURCHASES)
        end
      end
    end

    def delete_expired_sandboxes
      expired.find_each(&:destroy!)
    end
  end

  def sandbox?
    expires_at.present?
  end
end
