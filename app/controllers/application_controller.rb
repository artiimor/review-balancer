# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def ensure_token
    if current_user && tokens_not_configured
      redirect_to configuration_path, alert: t('controllers.application.github_token_required')
    end
  end

  private

  def tokens_not_configured
    current_user.configuration&.github_access_token.blank? && current_user.configuration&.gitlab_access_token.blank?
  end
end
