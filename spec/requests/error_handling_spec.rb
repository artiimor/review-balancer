# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application-wide error handling', type: :request do
  let(:user) { create(:user, email: 'user@example.com') }

  before(:example) { sign_in user }

  describe 'a request missing a required top-level param' do
    it 'redirects with a generic message instead of raising ActionController::ParameterMissing' do
      post repositories_path, params: {}, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('La solicitud no es válida.')
    end
  end

  describe 'when Active Record Encryption is misconfigured (missing AR_ENCRYPTION_* keys)' do
    it 'renders a generic message instead of raising on any controller, not just Configuration' do
      allow_any_instance_of(Configuration).to receive(:github_access_token)
        .and_raise(ActiveRecord::Encryption::Errors::Configuration)

      get repositories_path

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to eq('Error. Por favor, contacte con un administrador.')
    end

    it 'does not redirect (a redirect here would loop: root_path -> repositories_path -> ensure_token -> same error)' do
      allow_any_instance_of(Configuration).to receive(:github_access_token)
        .and_raise(ActiveRecord::Encryption::Errors::Configuration)

      get repositories_path

      expect(response).not_to be_redirect
    end
  end
end
