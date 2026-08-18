# frozen_string_literal: true

class ConfigurationController < ApplicationController
  before_action :authenticate_user!

  rescue_from ActiveRecord::Encryption::Errors::Base, with: :handle_encryption_error

  LOCKED_TOKEN_ALERTS = {
    github_access_token: 'controllers.configuration.github_token_locked',
    gitlab_access_token: 'controllers.configuration.gitlab_token_locked'
  }.freeze

  def show
    @configuration = current_user.configuration || current_user.build_configuration
  end

  def update
    @configuration = current_user.configuration || current_user.build_configuration

    if locked_token_alert
      redirect_to configuration_path, alert: t(locked_token_alert)
      return
    end

    if @configuration.update(configuration_params)
      redirect_to configuration_path, notice: t('controllers.configuration.updated')
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy_github_token
    @configuration = current_user.configuration
    @configuration&.update(github_access_token: nil)

    redirect_to configuration_path, notice: t('controllers.configuration.github_token_removed')
  end

  def destroy_gitlab_token
    @configuration = current_user.configuration
    @configuration&.update(gitlab_access_token: nil)

    redirect_to configuration_path, notice: t('controllers.configuration.gitlab_token_removed')
  end

  private

  def handle_encryption_error(exception)
    Rails.logger.error("ConfigurationController: #{exception.class} - #{exception.message}")
    redirect_to root_path, alert: t('controllers.configuration.encryption_unavailable')
  end

  def locked_token_alert
    LOCKED_TOKEN_ALERTS.each do |field, alert_key|
      next unless configuration_params[field].present? && @configuration.public_send(field).present?

      return alert_key
    end

    nil
  end

  def configuration_params
    params.require(:configuration).permit(:github_access_token, :gitlab_access_token, :gitlab_url, :lookback_months)
  end
end
