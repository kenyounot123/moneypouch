class SandboxesController < ApplicationController
  allow_unauthenticated_access
  only_in_demo
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "That's a lot of sandboxes. Try again in a few minutes." }

  def create
    start_new_session_for User.create_sandbox
    redirect_to root_path
  end
end
