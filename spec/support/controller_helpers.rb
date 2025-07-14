module ControllerHelpers
  def json_response
    JSON.parse(response.body)
  end

  def expect_success_response
    expect(response).to have_http_status(:success)
  end

  def expect_redirect_to(path)
    expect(response).to redirect_to(path)
  end

  def expect_unprocessable_entity
    expect(response).to have_http_status(:unprocessable_entity)
  end

  def expect_not_found
    expect(response).to have_http_status(:not_found)
  end

  def expect_forbidden
    expect(response).to have_http_status(:forbidden)
  end

  def expect_unauthorized
    expect(response).to have_http_status(:unauthorized)
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
  config.include ControllerHelpers, type: :request
end
