require "test_helper"

class FestivalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:committee_member)
    @festival = festivals(:summer_festival)
    sign_in @user
  end

  test "should get index" do
    get festivals_url
    assert_response :success
  end

  test "should get show" do
    get festival_url(@festival)
    assert_response :success
  end

  test "should get new" do
    get new_festival_url
    assert_response :success
  end

  test "should create festival" do
    assert_difference("Festival.count") do
      post festivals_url, params: {
        festival: {
          name: "Test Festival",
          description: "Test description",
          start_date: 1.month.from_now,
          end_date: 1.month.from_now + 3.days,
          location: "Test Location",
          budget: 50000,
          status: "planning"
        }
      }
    end
    assert_redirected_to festival_url(Festival.last)
  end

  test "should get edit" do
    get edit_festival_url(@festival)
    assert_response :success
  end

  test "should update festival" do
    patch festival_url(@festival), params: {
      festival: {
        name: "Updated Festival Name"
      }
    }
    assert_redirected_to festival_url(@festival)
  end

  test "should destroy festival" do
    assert_difference("Festival.count", -1) do
      delete festival_url(@festival)
    end
    assert_redirected_to festivals_url
  end

  test "should get gantt" do
    get festival_gantt_url(@festival)
    assert_response :success
  end
end
