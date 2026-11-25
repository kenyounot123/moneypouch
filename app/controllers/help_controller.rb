class HelpController < ApplicationController
  def show
    @sections = Help::Topic.sections
  end
end
