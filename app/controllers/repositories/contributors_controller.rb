# frozen_string_literal: true

module Repositories
  class ContributorsController < ApplicationController
    before_action :authenticate_user!

    def index
      @repository = current_user.repositories.find(params[:repository_id])
      @contributors = @repository.contributors
                                  .select('contributors.*, repository_contributors.active AS active')
                                  .order(created_at: :desc)
    end

    def update
      @repository = current_user.repositories.find(params[:repository_id])
      @contributor = @repository.contributors.find(params[:id])
      repository_contributor = @repository.repository_contributors.find_by!(contributor: @contributor)

      repository_contributor.update(active: update_params[:active]) if update_params.key?(:active)
      @contributor.update(update_params.except(:active))

      redirect_to repository_contributors_path(@repository)
    end

    private

    def update_params
      params.require(:contributor).permit(:name, :active)
    end
  end
end
