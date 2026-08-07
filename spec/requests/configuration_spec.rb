# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Configuration', type: :request do
  let(:user) { create(:user) }

  before(:example) { sign_in user }

  describe '#index' do
    it 'redirects to the sign in page when not authenticated' do
      sign_out user

      get configuration_path

      expect(response).to redirect_to(new_user_session_path)
    end

    context 'when the user has no GitHub access token yet' do
      before { user.configuration.update!(github_access_token: nil) }

      it 'renders the form to set a token' do
        get configuration_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Token de acceso de GitHub')
      end
    end

    context 'when the user already has a GitHub access token' do
      it 'renders the locked state without exposing the token' do
        get configuration_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Token configurado')
        expect(response.body).not_to include(user.configuration.github_access_token)
      end
    end

    context 'when the user has no configuration record yet' do
      before do
        user.configuration.destroy
        user.reload
      end

      it 'builds one on the fly and renders the form' do
        get configuration_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Token de acceso de GitHub')
      end
    end
  end

  describe '#update' do
    context 'when the user has no GitHub access token yet' do
      before { user.configuration.update!(github_access_token: nil) }

      it 'sets the token and redirects with a notice' do
        patch configuration_path, params: { configuration: { github_access_token: 'ghp_new_token' } }

        expect(response).to redirect_to(configuration_path)
        expect(flash[:notice]).to eq('Configuración actualizada correctamente.')
        expect(user.configuration.reload.github_access_token).to eq('ghp_new_token')
      end

      it 're-renders the form when saving fails' do
        allow_any_instance_of(Configuration).to receive(:update).and_return(false)

        patch configuration_path, params: { configuration: { github_access_token: 'ghp_new_token' } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when the user already has a GitHub access token' do
      it 'does not change the token and redirects with an alert' do
        original_token = user.configuration.github_access_token

        patch configuration_path, params: { configuration: { github_access_token: 'ghp_attempted_override' } }

        expect(response).to redirect_to(configuration_path)
        expect(flash[:alert]).to eq('El token de GitHub ya está configurado y no se puede cambiar.')
        expect(user.configuration.reload.github_access_token).to eq(original_token)
      end
    end
  end

  describe '#update gitlab_url' do
    before { user.configuration.update!(gitlab_access_token: nil, gitlab_url: nil) }

    it 'sets a custom GitLab URL alongside the token' do
      patch configuration_path, params: {
        configuration: { gitlab_access_token: 'glpat_new_token', gitlab_url: 'https://gitlab.example.com' }
      }

      expect(response).to redirect_to(configuration_path)
      expect(user.configuration.reload.gitlab_url).to eq('https://gitlab.example.com')
    end
  end

  describe '#destroy_github_token' do
    it 'clears the token and redirects with a notice' do
      delete destroy_github_token_path

      expect(response).to redirect_to(configuration_path)
      expect(flash[:notice]).to eq('Token de GitHub eliminado.')
      expect(user.configuration.reload.github_access_token).to be_nil
    end

    it 'does not raise when the user has no configuration record' do
      user.configuration.destroy
      user.reload

      delete destroy_github_token_path

      expect(response).to redirect_to(configuration_path)
    end
  end

  describe '#destroy_gitlab_token' do
    it 'clears the token and redirects with a notice' do
      delete destroy_gitlab_token_path

      expect(response).to redirect_to(configuration_path)
      expect(flash[:notice]).to eq('Token de GitLab eliminado.')
      expect(user.configuration.reload.gitlab_access_token).to be_nil
    end

    it 'does not raise when the user has no configuration record' do
      user.configuration.destroy
      user.reload

      delete destroy_gitlab_token_path

      expect(response).to redirect_to(configuration_path)
    end
  end
end
