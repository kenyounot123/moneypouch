class WelcomeController < ApplicationController
  def index
    @draft = Transaction::Draft.parse("", user: Current.user, today: Date.current)
  end
end
