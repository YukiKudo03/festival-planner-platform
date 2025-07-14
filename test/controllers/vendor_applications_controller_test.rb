require "test_helper"

class VendorApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:vendor)
    @festival = festivals(:summer_festival)
    @vendor_application = vendor_applications(:food_truck)
    sign_in @user
  end

  test "should get index" do
    get vendor_applications_url
    assert_response :success
  end

  test "should get show" do
    get festival_vendor_application_url(@festival, @vendor_application)
    assert_response :success
  end

  test "should get new" do
    get new_festival_vendor_application_url(@festival)
    assert_response :success
  end

  test "should create vendor application" do
    assert_difference("VendorApplication.count") do
      post festival_vendor_applications_url(@festival), params: {
        vendor_application: {
          business_name: "New Test Business",
          business_type: "Food Service",
          description: "Test description for new business application",
          requirements: "Basic requirements"
        }
      }
    end
    assert_redirected_to festival_vendor_application_url(@festival, VendorApplication.last)
  end

  test "should get edit" do
    get edit_festival_vendor_application_url(@festival, @vendor_application)
    assert_response :success
  end

  test "should update vendor application" do
    patch festival_vendor_application_url(@festival, @vendor_application), params: {
      vendor_application: {
        business_name: "Updated Business Name"
      }
    }
    assert_redirected_to festival_vendor_application_url(@festival, @vendor_application)
  end

  test "should destroy vendor application" do
    assert_difference("VendorApplication.count", -1) do
      delete festival_vendor_application_url(@festival, @vendor_application)
    end
    assert_redirected_to festival_url(@festival)
  end
end
