# frozen_string_literal: true

class ConfigurationController < ApplicationController
  before_action :authenticate_user!

  LOCKED_TOKEN_ALERTS = {
    github_access_token: 'The GitHub token is already set and cannot be changed.',
    gitlab_access_token: 'The GitLab token is already set and cannot be changed.'
  }.freeze

  def show
    @configuration = current_user.configuration || current_user.build_configuration
  end

  def update
    @configuration = current_user.configuration || current_user.build_configuration

    if locked_token_alert
      redirect_to configuration_path, alert: locked_token_alert
      return
    end

    if @configuration.update(configuration_params)
      redirect_to configuration_path, notice: 'Configuration updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy_github_token
    @configuration = current_user.configuration
    @configuration&.update(github_access_token: nil)

    redirect_to configuration_path, notice: 'GitHub token removed.'
  end

  def destroy_gitlab_token
    @configuration = current_user.configuration
    @configuration&.update(gitlab_access_token: nil)

    redirect_to configuration_path, notice: 'GitLab token removed.'
  end

  private

  def locked_token_alert
    LOCKED_TOKEN_ALERTS.each do |field, alert|
      next unless configuration_params[field].present? && @configuration.public_send(field).present?

      return alert
    end

    nil
  end

  def configuration_params
    params.require(:configuration).permit(:github_access_token, :gitlab_access_token, :gitlab_url)
  end
end
