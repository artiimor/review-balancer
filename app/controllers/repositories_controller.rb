# frozen_string_literal: true

class RepositoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @repositories = current_user.repositories
  end

  def new
    @repository = Repository.new
  end

  def create
    @repository = current_user.repositories.new(repository_params)

    if @repository.save
      ImportRepositoryContributorsJob.perform_later(@repository.id)
      ImportRepositoryPullRequestsJob.perform_later(@repository.id)

      render turbo_stream: [
        turbo_stream.remove('new-repository-modal'),
        turbo_stream.append('repositories', partial: 'repositories/repository', locals: { repository: @repository })
      ]
    else
      render turbo_stream: turbo_stream.replace('new-repository-modal',
                                                partial: 'repositories/modal',
                                                locals: { repository: @repository })
    end
  end

  def destroy
    @repository = current_user.repositories.find(params[:id])

    if @repository.destroy
      render turbo_stream: turbo_stream.remove(@repository)
    else
      render turbo_stream: [turbo_stream.update('general_error',
                                                partial: 'repositories/error_message',
                                                locals: { message: 'No se puede eliminar el repositorio' })]
    end
  end

  def show
    @repository = current_user.repositories.find(params[:id])
    @pull_requests = @repository.pull_requests.includes(review_assignments: :reviewer)
    @dashboard = RepositoryDashboardData.call(@repository)
  end

  private

  def repository_params
    params.require(:repository).permit(:github_full_name, :webhook_secret)
  end
end
