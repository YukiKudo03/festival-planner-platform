module AuthenticationHelpers
  def authenticate_controller_user(user)
    # Stub all authentication-related methods
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:user_signed_in?).and_return(true)
    allow(controller).to receive(:authenticate_user!).and_return(true)

    # Stub authorization methods
    allow(controller).to receive(:can?).and_return(true)
    allow(controller).to receive(:authorize!).and_return(true)

    # Create a mock ability that allows everything
    ability = double('Ability')
    allow(ability).to receive(:can?).and_return(true)
    allow(controller).to receive(:current_ability).and_return(ability)

    # Mock browser checks
    allow(controller).to receive(:allow_browser).and_return(true)

    user
  end

  def authenticate_request_user(user)
    # For request specs, use Devise test helpers
    sign_in user
  end

  def authenticate_system_user(user)
    # For system specs, perform actual login
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Sign in'
    expect(page).to have_content('Signed in successfully')
    user
  end

  def create_authenticated_user(role: :resident, **attributes)
    user = create(:user, role: role, **attributes)
    case RSpec.current_example.metadata[:type]
    when :controller
      authenticate_controller_user(user)
    when :request
      authenticate_request_user(user)
    when :system
      authenticate_system_user(user)
    end
    user
  end

  def create_authenticated_admin(**attributes)
    create_authenticated_user(role: :admin, **attributes)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :controller
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
