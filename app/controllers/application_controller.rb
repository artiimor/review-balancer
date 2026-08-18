# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  rescue_from ActionController::ParameterMissing, with: :render_bad_request_error
  rescue_from ActiveRecord::Encryption::Errors::Base, with: :render_encryption_error

  def ensure_token
    return unless current_user && tokens_not_configured

    redirect_to configuration_path, alert: t('controllers.application.github_token_required')
  end

  private

  def tokens_not_configured
    current_user.configuration&.github_access_token.blank? && current_user.configuration&.gitlab_access_token.blank?
  end

  def render_bad_request_error
    redirect_to root_path, alert: t('controllers.application.errors.bad_request')
  end

  def render_encryption_error(exception)
    Rails.logger.error("#{self.class}: #{exception.class} - #{exception.message}")

    # Redirect = infinite loop :(
    render plain: t('controllers.application.errors.encryption_unavailable'), status: :internal_server_error
  end
end
