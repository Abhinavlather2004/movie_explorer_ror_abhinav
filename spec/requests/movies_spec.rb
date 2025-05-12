require 'rails_helper'

RSpec.describe 'Api::V1::Movies', type: :request do
  let(:supervisor) { create(:user, role: 'supervisor') }
  let(:regular_user) { create(:user, role: 'user') }
  let(:movie) { create(:movie) }
  let(:jwt_token) { Warden::JWTAuth::UserEncoder.new.call(supervisor, :user, nil).first }
  let(:regular_user_token) { Warden::JWTAuth::UserEncoder.new.call(regular_user, :user, nil).first }
  let(:valid_movie_params) do
    {
      movie: {
        title: 'Test Movie',
        genre: 'Action',
        release_year: 2023,
        rating: 8.5,
        director: 'John Doe',
        duration: 120,
        description: 'An exciting action movie',
        main_lead: 'Jane Smith',
        streaming_platform: 'Netflix',
        premium: false,
        poster: Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'poster.jpg'), 'image/jpeg'),
        banner: Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'files', 'banner.jpg'), 'image/jpeg')
      }
    }
  end
  let(:invalid_movie_params) do
    {
      movie: {
        title: '', # Invalid: title is required
        genre: 'Action',
        release_year: 2023,
        rating: 8.5,
        director: 'John Doe',
        duration: 120,
        description: 'An exciting action movie',
        main_lead: 'Jane Smith',
        streaming_platform: 'Netflix',
        premium: false
      }
    }
  end

  before do
    # Mock Active Storage URLs to avoid serialization errors
    allow_any_instance_of(MovieSerializer).to receive(:poster_url).and_return('http://example.com/poster.jpg')
    allow_any_instance_of(MovieSerializer).to receive(:banner_url).and_return('http://example.com/banner.jpg')
  end

  describe 'GET /api/v1/movies' do
    it 'returns a paginated list of movies' do
      create_list(:movie, 15)
      get '/api/v1/movies', params: { page: 1, per_page: 10 }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['movies'].size).to eq(10)
      expect(data['pagination']['current_page']).to eq(1)
      expect(data['pagination']['total_pages']).to eq(2)
      expect(data['pagination']['total_count']).to eq(15)
    end

    it 'filters movies by title' do
      create(:movie, title: 'The Matrix')
      get '/api/v1/movies', params: { title: 'Matrix' }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['movies'].size).to eq(1)
      expect(data['movies'].first['title']).to eq('The Matrix')
    end

    it 'filters movies by genre' do
      create(:movie, genre: 'Sci-Fi')
      get '/api/v1/movies', params: { genre: 'Sci-Fi' }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['movies'].size).to eq(1)
      expect(data['movies'].first['genre']).to eq('Sci-Fi')
    end

    it 'returns not found when no movies match filters' do
      get '/api/v1/movies', params: { title: 'Nonexistent' }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('No movies found')
    end
  end

  describe 'GET /api/v1/movies/:id' do
    it 'returns the movie when it exists' do
      get "/api/v1/movies/#{movie.id}", as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['title']).to eq(movie.title)
      expect(data['genre']).to eq(movie.genre)
    end

    it 'returns not found when movie does not exist' do
      get '/api/v1/movies/999', as: :json
      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)['error']).to eq('Movie not found')
    end
  end

  describe 'POST /api/v1/movies' do
    context 'when signed in as supervisor' do
      before { sign_in supervisor }

      it 'creates a movie with valid attributes' do
        allow(FcmService).to receive(:new).and_return(double(send_notification: { status_code: 200 }))
        post '/api/v1/movies', params: valid_movie_params, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:created)
        data = JSON.parse(response.body)
        expect(data['message']).to eq('Movie added successfully')
        expect(data['movie']['title']).to eq('Test Movie')
      end

      it 'returns errors with invalid attributes' do
        post '/api/v1/movies', params: invalid_movie_params, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include(/Title can't be blank/)
      end
    end

    context 'when signed in as regular user' do
      before { sign_in regular_user }

      it 'returns forbidden status' do
        post '/api/v1/movies', params: valid_movie_params, headers: { 'Authorization' => "Bearer #{regular_user_token}" }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']).to eq('Forbidden: Supervisor access required')
      end
    end

    context 'when not signed in' do
      it 'returns unauthorized status' do
        post '/api/v1/movies', params: valid_movie_params, as: :json
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('No token provided. Please sign in.')
      end
    end
  end

  describe 'PATCH /api/v1/movies/:id' do
    context 'when signed in as supervisor' do
      before { sign_in supervisor }

      it 'updates the movie with valid attributes' do
        patch "/api/v1/movies/#{movie.id}", params: { movie: { title: 'Updated Title' } }, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['title']).to eq('Updated Title')
        expect(movie.reload.title).to eq('Updated Title')
      end

      it 'returns errors with invalid attributes' do
        patch "/api/v1/movies/#{movie.id}", params: invalid_movie_params, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors']).to include(/Title can't be blank/)
      end

      it 'returns not found when movie does not exist' do
        patch '/api/v1/movies/999', params: valid_movie_params, headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Movie not found')
      end
    end

    context 'when signed in as regular user' do
      before { sign_in regular_user }

      it 'returns forbidden status' do
        patch "/api/v1/movies/#{movie.id}", params: valid_movie_params, headers: { 'Authorization' => "Bearer #{regular_user_token}" }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']).to eq('Forbidden: Supervisor access required')
      end
    end

    context 'when not signed in' do
      it 'returns unauthorized status' do
        patch "/api/v1/movies/#{movie.id}", params: valid_movie_params, as: :json
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('No token provided. Please sign in.')
      end
    end
  end

  describe 'DELETE /api/v1/movies/:id' do
    context 'when signed in as supervisor' do
      before { sign_in supervisor }

      it 'deletes the movie' do
        delete "/api/v1/movies/#{movie.id}", headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:no_content)
        expect(Movie.find_by(id: movie.id)).to be_nil
      end

      it 'returns not found when movie does not exist' do
        delete '/api/v1/movies/999', headers: { 'Authorization' => "Bearer #{jwt_token}" }, as: :json
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Movie not found')
      end
    end

    context 'when signed in as regular user' do
      before { sign_in regular_user }

      it 'returns forbidden status' do
        delete "/api/v1/movies/#{movie.id}", headers: { 'Authorization' => "Bearer #{regular_user_token}" }, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['error']).to eq('Forbidden: Supervisor access required')
      end
    end

    context 'when not signed in' do
      it 'returns unauthorized status' do
        delete "/api/v1/movies/#{movie.id}", as: :json
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('No token provided. Please sign in.')
      end
    end
  end
end