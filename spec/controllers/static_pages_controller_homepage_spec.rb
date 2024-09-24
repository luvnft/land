# frozen_string_literal: true

RSpec.describe StaticPagesController do
  render_views

  describe 'GET /' do
    context 'when logged out' do
      it 'returns a 200 status code and login link' do
        get :homepage

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Log In')
      end
    end

    context 'when logged in' do
      let(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it 'returns a 200 status code and logout link' do
        get :homepage

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Log Out')
      end
    end
  end
end