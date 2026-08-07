# frozen_string_literal: true

class RepositoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_github_token, except: [:destroy], if: -> { user_signed_in? }

  def index
    @repositories = current_user.repositories
  end

  def new
    @repository = Repository.new
  end

  def create
    @repository = current_user.repositories.new(repository_params)

    if @repository.save
      enqueue_import_jobs(@repository)
      render turbo_stream: [turbo_stream.remove('new-repository-modal'),
                            turbo_stream.append('repositories',
                                                partial: 'repositories/repository',
                                                locals: { repository: @repository })]
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
    params.require(:repository).permit(:github_full_name, :webhook_secret, :provider)
  end

  def enqueue_import_jobs(repository)
    access_token = if repository.provider == 'gitlab'
                     current_user.configuration&.gitlab_access_token
                   else
                     current_user.configuration&.github_access_token
                   end

    ImportRepositoryContributorsJob.perform_later(repository.id, access_token)
    ImportRepositoryPullRequestsJob.perform_later(repository.id, access_token)
  end
end
