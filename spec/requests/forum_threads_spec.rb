require 'rails_helper'

RSpec.describe "ForumThreads", type: :request do
  describe "GET /show" do
    it "returns http success" do
      get "/forum_threads/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/forum_threads/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /create" do
    it "returns http success" do
      get "/forum_threads/create"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/forum_threads/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/forum_threads/update"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /destroy" do
    it "returns http success" do
      get "/forum_threads/destroy"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /pin" do
    it "returns http success" do
      get "/forum_threads/pin"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /lock" do
    it "returns http success" do
      get "/forum_threads/lock"
      expect(response).to have_http_status(:success)
    end
  end

end
