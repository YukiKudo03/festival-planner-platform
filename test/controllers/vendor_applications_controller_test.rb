require "test_helper"

class VendorApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get vendor_applications_index_url
    assert_response :success
  end

  test "should get show" do
    get vendor_applications_show_url
    assert_response :success
  end

  test "should get new" do
    get vendor_applications_new_url
    assert_response :success
  end

  test "should get create" do
    get vendor_applications_create_url
    assert_response :success
  end

  test "should get edit" do
    get vendor_applications_edit_url
    assert_response :success
  end

  test "should get update" do
    get vendor_applications_update_url
    assert_response :success
  end

  test "should get destroy" do
    get vendor_applications_destroy_url
    assert_response :success
  end
end
