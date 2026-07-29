# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @repositories = current_user.repositories
  end
end
