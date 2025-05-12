require 'rails_helper'

RSpec.describe 'Api::V1::Subscriptions', type: :request do
  let(:user) { create(:user) }
  let(:subscription) { create(:subscription, user: user) }
  let(:jwt_token) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first }

  before do
    # Validate setup
    raise "User creation failed" unless user.persisted?
    user.subscription = subscription
    user.save!
    raise "Subscription creation failed" unless subscription.persisted?
    raise "JWT token missing" unless jwt_token.present?

    # Global Stripe mocks
    allow(Stripe::Checkout::Session).to receive(:create).and_return(
      double(id: 'sess_123', url: 'https://checkout.stripe.com/sess_123')
    )
    allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(
      double(
        id: 'sess_123',
        customer: subscription.stripe_customer_id,
        subscription: 'sub_123',
        metadata: Struct.new(:plan_type).new('1_day')
      )
    )
  end

  describe 'POST /api/v1/subscriptions' do
    context 'when signed in' do
      before { sign_in user }

      it 'creates a checkout session with valid plan type' do
        post '/api/v1/subscriptions', params: { plan_type: '1_day' }, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:ok)
      end

      it 'returns bad request with invalid plan type' do
        post '/api/v1/subscriptions', params: { plan_type: 'invalid' }, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when not signed in' do
      it 'returns unauthorized status' do
        post '/api/v1/subscriptions', params: { plan_type: '1_day' }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/subscriptions/success' do
    it 'updates subscription' do
      get '/api/v1/subscriptions/success', params: { session_id: 'sess_123' }, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'returns not found when subscription does not exist' do
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(
        double(
          customer: 'cus_nonexistent',
          subscription: 'sub_123',
          metadata: Struct.new(:plan_type).new('1_day')
        )
      )
      get '/api/v1/subscriptions/success', params: { session_id: 'sess_123' }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Subscription not found')
    end
  end

  describe 'GET /api/v1/subscriptions/status' do
    context 'when signed in' do
      before { sign_in user }

      it 'returns subscription status' do
        get '/api/v1/subscriptions/status', headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when not signed in' do
      it 'returns unauthorized status' do
        get '/api/v1/subscriptions/status', as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end