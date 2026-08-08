# frozen_string_literal: true

module Repositories
  class ContributorsController < ApplicationController
    before_action :authenticate_user!

    def index
      @repository = current_user.repositories.find(params[:repository_id])
      @contributors = @repository.contributors.unscope(where: :active).order(created_at: :desc)
    end

    def update
      @repository = current_user.repositories.find(params[:repository_id])
      @contributor = @repository.contributors.unscope(where: :active).find(params[:id])
      @contributor.update(update_params)
      redirect_to repository_contributors_path(@repository)
    end

    private

    def update_params
      params.require(:contributor).permit(:name, :active)
    end
  end
end
