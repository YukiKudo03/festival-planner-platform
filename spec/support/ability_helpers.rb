module AbilityHelpers
  def ability_for(user)
    Ability.new(user)
  end

  def expect_can(user, action, subject)
    expect(ability_for(user)).to be_able_to(action, subject)
  end

  def expect_cannot(user, action, subject)
    expect(ability_for(user)).not_to be_able_to(action, subject)
  end

  def sign_in_as_admin
    admin = create(:user, role: :admin)
    sign_in admin
    admin
  end

  def sign_in_as_user(role = :resident)
    user = create(:user, role: role)
    sign_in user
    user
  end
end

RSpec.configure do |config|
  config.include AbilityHelpers, type: :controller
  config.include AbilityHelpers, type: :request
  config.include AbilityHelpers, type: :feature
end
