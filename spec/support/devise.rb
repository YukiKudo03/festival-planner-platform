RSpec.configure do |config|
  # Properly configure Devise for different test types
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Set up Warden test mode
  config.before(:suite) do
    Warden.test_mode!
  end

  config.after(:each) do
    Warden.test_reset!
  end

  # Configure controller test defaults - ensure proper request setup
  config.before(:each, type: :controller) do
    if @request
      @request.env["devise.mapping"] = Devise.mappings[:user]
      @request.env["HTTP_ACCEPT"] = "text/html"
      @request.env["rack.session"] = {}
    end
  end

  # Configure system test authentication helpers
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # Add helper method for controller tests
  config.include(Module.new do
    def sign_in_for_test(user)
      # Mock the authentication methods directly
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:user_signed_in?).and_return(true)
      allow(controller).to receive(:authenticate_user!).and_return(true)

      # Mock the authorization methods
      allow(controller).to receive(:can?).and_return(true)
      allow(controller).to receive(:authorize!).and_return(true)

      # Mock browser version check
      allow(controller).to receive(:allow_browser).and_return(true)
    end
  end, type: :controller)
end
