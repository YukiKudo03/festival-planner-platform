RSpec.configure do |config|
  # Configure Capybara for system tests
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  # Configure Chrome headless for JavaScript tests
  config.before(:each, type: :system, js: true) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  end

  # Helper methods for system tests
  config.include Module.new {
    def sign_in_user(user = nil)
      user ||= create(:user)
      visit new_user_session_path
      fill_in 'Email', with: user.email
      fill_in 'Password', with: user.password
      click_button 'Sign in'
      user
    end

    def sign_out_user
      visit destroy_user_session_path
    end

    def create_and_sign_in_admin
      admin = create(:user, role: :admin)
      sign_in_user(admin)
      admin
    end

    def create_and_sign_in_user(role = :resident)
      user = create(:user, role: role)
      sign_in_user(user)
      user
    end
  }, type: :system
end

# Configure Capybara settings
Capybara.configure do |config|
  config.server_port = 3001
  config.default_max_wait_time = 5
  config.exact = true
  config.match = :prefer_exact
  config.visible_text_only = true
end

# Configure Chrome driver options
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options
  )
end
