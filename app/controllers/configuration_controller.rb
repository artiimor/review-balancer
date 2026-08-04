# frozen_string_literal: true

class ConfigurationController < ApplicationController
  before_action :authenticate_user!

  def show
    @configuration = current_user.configuration || current_user.build_configuration
  end

  def update
    @configuration = current_user.configuration || current_user.build_configuration

    if @configuration.github_access_token.present?
      redirect_to configuration_path, alert: 'The GitHub token is already set and cannot be changed.'
      return
    end

    if @configuration.update(configuration_params)
      redirect_to configuration_path, notice: 'Configuration updated successfully.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @configuration = current_user.configuration
    @configuration&.update(github_access_token: nil)

    redirect_to configuration_path, notice: 'GitHub token removed.'
  end

  private

  def configuration_params
    params.require(:configuration).permit(:github_access_token)
  end
end
