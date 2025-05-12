require 'rails_helper'

RSpec.describe 'User Authentication', type: :request do
  let(:user) { create(:user, password: 'password123', notifications_enabled: true) }
  let(:jwt_token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  describe 'POST /users' do
    it 'creates a user with valid data' do
      user_data = {
        user: {
          email: 'test@example.com',
          password: 'password123',
          name: 'Test User',
          mobile_number: '1234567890'
        }
      }
      post '/users', params: user_data, as: :json
      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data['email']).to eq('test@example.com')
      expect(data['role']).to eq('user')
      expect(data['token']).to be_present
    end

    it 'fails with invalid data' do
      user_data = {
        user: {
          email: '',
          password: 'password123',
          name: 'Test User',
          mobile_number: '1234567890'
        }
      }
      post '/users', params: user_data, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)).to have_key('errors')
    end
  end

  describe 'POST /users/sign_in' do
    let!(:existing_user) { create(:user, email: 'user@example.com', password: 'password123') }

    it 'logs in with correct credentials' do
      credentials = {
        user: {
          email: 'user@example.com',
          password: 'password123'
        }
      }
      post '/users/sign_in', params: credentials, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['email']).to eq('user@example.com')
      expect(data['token']).to be_present
    end

    it 'fails with incorrect credentials' do
      credentials = {
        user: {
          email: 'wrong@example.com',
          password: 'wrongpass'
        }
      }
      post '/users/sign_in', params: credentials, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('Invalid Email or password.')
    end
  end

  describe 'DELETE /users/sign_out' do
    it 'logs out with valid token' do
      allow(JwtBlacklist).to receive(:revoked?).and_return(false)
      allow(JwtBlacklist).to receive(:revoke)
      delete '/users/sign_out', headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['message']).to eq('Signed out successfully.')
    end

    it 'fails without token' do
      delete '/users/sign_out', as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('No token provided. Please include a valid Bearer token.')
    end
  end

  describe 'GET /api/v1/current_user' do
    it 'returns current user when signed in' do
      sign_in user
      get '/api/v1/current_user', headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['email']).to eq(user.email)
      expect(data['id']).to eq(user.id)
      expect(data['name']).to eq(user.name)
    end

    it 'fails when not signed in' do
      get '/api/v1/current_user', as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('No token provided. Please sign in.')
    end
  end

  describe 'POST /api/v1/update_device_token' do
    it 'updates device token when signed in' do
      sign_in user
      post '/api/v1/update_device_token', params: { device_token: 'abc123' }, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['message']).to eq('Device token updated successfully')
      expect(user.reload.device_token).to eq('abc123')
    end

    it 'fails with invalid device token when signed in' do
      sign_in user
      allow_any_instance_of(User).to receive(:update).and_return(false)
      allow_any_instance_of(User).to receive(:errors).and_return(double(full_messages: ['Device token is invalid']))
      post '/api/v1/update_device_token', params: { device_token: '' }, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include('Device token is invalid')
    end

    it 'fails when not signed in' do
      post '/api/v1/update_device_token', params: { device_token: 'abc123' }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('No token provided. Please sign in.')
    end
  end

  describe 'POST /api/v1/toggle_notifications' do
    it 'toggles notifications when signed in' do
      sign_in user
      post '/api/v1/toggle_notifications', headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['message']).to eq('Notifications preference updated')
      expect(data['notifications_enabled']).to eq(false)
      expect(user.reload.notifications_enabled).to eq(false)
    end

    it 'fails when update fails' do
      sign_in user
      allow_any_instance_of(User).to receive(:update).and_return(false)
      allow_any_instance_of(User).to receive(:errors).and_return(double(full_messages: ['Notifications update failed']))
      post '/api/v1/toggle_notifications', headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors']).to include('Notifications update failed')
    end

    it 'fails when not signed in' do
      post '/api/v1/toggle_notifications', as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('No token provided. Please sign in.')
    end
  end
end