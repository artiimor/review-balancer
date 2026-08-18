# frozen_string_literal: true

class RepositoriesController < ApplicationController
  ALLOWED_PER_PAGE = [10, 20, 50, 100].freeze

  before_action :authenticate_user!
  before_action :ensure_token, except: [:destroy], if: -> { user_signed_in? }

  def index
    @repositories = current_user.repositories.order(created_at: :asc)
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
                                                locals: { message: t('controllers.repositories.destroy_error') })]
    end
  end

  def show
    @repository = current_user.repositories.find(params[:id])
    @per_page = ALLOWED_PER_PAGE.include?(params[:per].to_i) ? params[:per].to_i : 25
    @reviewers = @repository.active_contributors.order(:github_login)
    load_pull_requests
    @dashboard = RepositoryDashboardData.call(@repository)
  end

  private

  def load_pull_requests
    @filters = pull_request_filters
    @filters_active = @filters.values.any?(&:present?)
    @pull_requests = paginated_pull_requests
  end

  def pull_request_filters
    {
      q: params[:q],
      state: Array(params[:state]).reject(&:blank?),
      reviewer_id: Array(params[:reviewer_id]).reject(&:blank?),
      review_time: params[:review_time]
    }
  end

  def paginated_pull_requests
    filtered_pull_requests.includes(review_assignments: :reviewer)
                          .page(params[:page])
                          .per(@per_page)
                          .order(created_at: :desc)
  end

  def filtered_pull_requests
    scoped = @repository.pull_requests.search_by_query(@filters[:q]).with_state(@filters[:state])
    scoped.with_reviewer(@filters[:reviewer_id]).with_review_time(@filters[:review_time])
  end

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
