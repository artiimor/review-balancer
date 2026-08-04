# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  def ensure_github_token
    if current_user && current_user.configuration&.github_access_token.blank?
      redirect_to configuration_path, alert: t('configuration.github_token_required')
    end
  end
end
