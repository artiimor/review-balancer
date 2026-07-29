# frozen_string_literal: true

class RepositoriesController < ApplicationController
  def index
    @repositories = current_user.repositories
  end

  def new
    @repository = Repository.new
  end

  def create
    @repository = current_user.repositories.new(repository_params)

    if @repository.save
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

    if @repository.delete
      render turbo_stream: turbo_stream.remove(@repository)
    else
      render turbo_stream: [turbo_stream.update('general_error',
                                                partial: 'repositories/error_message',
                                                locals: { message: 'No se puede eliminar el repositorio' })]
    end
  end

  private

  def repository_params
    params.require(:repository).permit(:github_full_name, :webhook_secret)
  end
end
