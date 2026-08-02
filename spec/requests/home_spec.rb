# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe '#index' do
    context 'when the user is authenticated' do
      it 'redirects to the repositories page' do
        user = User.create!(email: 'user@example.com', password: 'password123')
        sign_in user

        get root_path

        expect(response).to redirect_to(repositories_path)
      end
    end

    context 'when the user is not authenticated' do
      it 'renders the landing page' do
        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('ReviewBalancer')
        expect(response.body).to include('Iniciar sesión')
      end
    end
  end
end
