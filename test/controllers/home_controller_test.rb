require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "should get index when logged in" do
    sign_in users(:admin)
    get root_url
    assert_response :success
  end

  test "should redirect to sign in when not logged in" do
    get root_url
    assert_redirected_to new_user_session_path
  end
end
