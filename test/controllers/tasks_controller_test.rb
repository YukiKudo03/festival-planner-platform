require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:committee_member)
    @festival = festivals(:summer_festival)
    @task = tasks(:venue_booking)
    sign_in @user
  end

  test "should get index" do
    get tasks_url
    assert_response :success
  end

  test "should get show" do
    get festival_task_url(@festival, @task)
    assert_response :success
  end

  test "should get new" do
    get new_festival_task_url(@festival)
    assert_response :success
  end

  test "should create task" do
    assert_difference('Task.count') do
      post festival_tasks_url(@festival), params: {
        task: {
          title: 'New Test Task',
          description: 'Test description',
          due_date: 1.week.from_now,
          priority: 'medium',
          status: 'pending'
        }
      }
    end
    assert_redirected_to festival_task_url(@festival, Task.last)
  end

  test "should get edit" do
    get edit_festival_task_url(@festival, @task)
    assert_response :success
  end

  test "should update task" do
    patch festival_task_url(@festival, @task), params: {
      task: {
        title: 'Updated Task Title'
      }
    }
    assert_redirected_to festival_task_url(@festival, @task)
  end

  test "should destroy task" do
    assert_difference('Task.count', -1) do
      delete festival_task_url(@festival, @task)
    end
    assert_redirected_to festival_url(@festival)
  end

  test "should get gantt" do
    get gantt_tasks_url
    puts "Response status: #{response.status}"
    puts "Response body: #{response.body}" if response.status != 200
    assert_response :success
  end
end
