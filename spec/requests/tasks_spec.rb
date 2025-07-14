require 'rails_helper'

RSpec.describe "Tasks", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:festival) { create(:festival, user: user) }
  let(:task) { create(:task, festival: festival, user: user) }
  let(:other_task) { create(:task) }

  before { sign_in user }

  describe "GET /festivals/:festival_id/tasks" do
    let!(:festival_task) { create(:task, festival: festival, user: user) }
    let!(:other_festival_task) { create(:task, festival: festival) }

    it "returns a successful response" do
      get festival_tasks_path(festival)
      expect(response).to be_successful
    end

    it "displays festival tasks" do
      get festival_tasks_path(festival)
      expect(response.body).to include(festival_task.title)
    end

    it "does not display tasks from other festivals" do
      other_task = create(:task)
      get festival_tasks_path(festival)
      expect(response.body).not_to include(other_task.title)
    end

    context "when user is not festival participant" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get festival_tasks_path(festival)
        expect(response).to redirect_to(festivals_path)
      end
    end

    context "with admin user" do
      before { sign_in admin }

      it "allows access to any festival's tasks" do
        get festival_tasks_path(festival)
        expect(response).to be_successful
      end
    end
  end

  describe "GET /festivals/:festival_id/tasks/:id" do
    it "returns a successful response" do
      get festival_task_path(festival, task)
      expect(response).to be_successful
    end

    it "assigns the task" do
      get festival_task_path(festival, task)
      expect(response.body).to include(task.title)
    end

    context "when task belongs to different festival" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get festival_task_path(festival, other_task)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when user is not festival participant" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get festival_task_path(festival, task)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "GET /festivals/:festival_id/tasks/new" do
    it "returns a successful response" do
      get new_festival_task_path(festival)
      expect(response).to be_successful
    end

    it "renders the new task form" do
      get new_festival_task_path(festival)
      expect(response.body).to include("New Task")
    end

    context "when user cannot access festival" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get new_festival_task_path(festival)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/tasks" do
    let(:valid_attributes) do
      {
        title: "Setup venue decorations",
        description: "Arrange flowers and lighting for the main stage",
        due_date: 1.week.from_now,
        priority: :high,
        status: :pending
      }
    end

    let(:invalid_attributes) do
      {
        title: "",
        description: "",
        due_date: nil
      }
    end

    context "with valid parameters" do
      it "creates a new task" do
        expect {
          post festival_tasks_path(festival), params: { task: valid_attributes }
        }.to change(Task, :count).by(1)
      end

      it "assigns the task to the current user" do
        post festival_tasks_path(festival), params: { task: valid_attributes }
        expect(Task.last.user).to eq(user)
      end

      it "assigns the task to the festival" do
        post festival_tasks_path(festival), params: { task: valid_attributes }
        expect(Task.last.festival).to eq(festival)
      end

      it "redirects to the created task" do
        post festival_tasks_path(festival), params: { task: valid_attributes }
        expect(response).to redirect_to(festival_task_path(festival, Task.last))
      end

      it "sets a success flash message" do
        post festival_tasks_path(festival), params: { task: valid_attributes }
        expect(flash[:notice]).to be_present
      end

      it "sends notification to festival organizers" do
        expect {
          post festival_tasks_path(festival), params: { task: valid_attributes }
        }.to change(Notification, :count)
      end
    end

    context "with invalid parameters" do
      it "does not create a task" do
        expect {
          post festival_tasks_path(festival), params: { task: invalid_attributes }
        }.not_to change(Task, :count)
      end

      it "renders the new template" do
        post festival_tasks_path(festival), params: { task: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it "returns unprocessable entity status" do
        post festival_tasks_path(festival), params: { task: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user cannot access festival" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        post festival_tasks_path(festival), params: { task: valid_attributes }
        expect(response).to redirect_to(festivals_path)
      end
    end

    context "with file attachments" do
      let(:attributes_with_files) do
        valid_attributes.merge(
          attachments: [
            fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')
          ]
        )
      end

      it "attaches files to the task" do
        post festival_tasks_path(festival), params: { task: attributes_with_files }
        expect(Task.last.attachments).to be_attached
      end
    end
  end

  describe "PATCH /festivals/:festival_id/tasks/:id" do
    let(:new_attributes) do
      {
        title: "Updated task title",
        description: "Updated task description",
        status: :in_progress
      }
    end

    context "with valid parameters" do
      it "updates the task" do
        patch festival_task_path(festival, task), params: { task: new_attributes }
        task.reload
        expect(task.title).to eq("Updated task title")
      end

      it "redirects to the task" do
        patch festival_task_path(festival, task), params: { task: new_attributes }
        expect(response).to redirect_to(festival_task_path(festival, task))
      end

      it "sets a success flash message" do
        patch festival_task_path(festival, task), params: { task: new_attributes }
        expect(flash[:notice]).to be_present
      end

      it "sends notification when status changes" do
        expect {
          patch festival_task_path(festival, task), params: { task: { status: :completed } }
        }.to change(Notification, :count)
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) { { title: "", due_date: nil } }

      it "does not update the task" do
        original_title = task.title
        patch festival_task_path(festival, task), params: { task: invalid_attributes }
        task.reload
        expect(task.title).to eq(original_title)
      end

      it "renders the edit template" do
        patch festival_task_path(festival, task), params: { task: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end

    context "when user is not task owner" do
      let(:other_user) { create(:user) }
      let(:other_user_task) { create(:task, festival: festival, user: other_user) }

      context "but is festival owner" do
        it "allows updates" do
          patch festival_task_path(festival, other_user_task), params: { task: new_attributes }
          expect(response).to redirect_to(festival_task_path(festival, other_user_task))
        end
      end

      context "and is not festival owner" do
        before { sign_in create(:user) }

        it "redirects to festivals index" do
          patch festival_task_path(festival, task), params: { task: new_attributes }
          expect(response).to redirect_to(festivals_path)
        end
      end
    end
  end

  describe "DELETE /festivals/:festival_id/tasks/:id" do
    let!(:task_to_delete) { create(:task, festival: festival, user: user) }

    context "when user is task owner" do
      it "destroys the task" do
        expect {
          delete festival_task_path(festival, task_to_delete)
        }.to change(Task, :count).by(-1)
      end

      it "redirects to tasks index" do
        delete festival_task_path(festival, task_to_delete)
        expect(response).to redirect_to(festival_tasks_path(festival))
      end

      it "sets a success flash message" do
        delete festival_task_path(festival, task_to_delete)
        expect(flash[:notice]).to be_present
      end
    end

    context "when user is festival owner but not task owner" do
      let(:other_user_task) { create(:task, festival: festival, user: create(:user)) }

      it "destroys the task" do
        expect {
          delete festival_task_path(festival, other_user_task)
        }.to change(Task, :count).by(-1)
      end
    end

    context "when user is admin" do
      before { sign_in admin }

      it "destroys the task" do
        expect {
          delete festival_task_path(festival, task_to_delete)
        }.to change(Task, :count).by(-1)
      end
    end

    context "when user cannot delete task" do
      before { sign_in create(:user) }

      it "does not destroy the task" do
        expect {
          delete festival_task_path(festival, task_to_delete)
        }.not_to change(Task, :count)
      end

      it "redirects to festivals index" do
        delete festival_task_path(festival, task_to_delete)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/tasks/:id/assign" do
    let(:assignee) { create(:user) }

    context "when user is festival owner" do
      it "assigns the task to specified user" do
        post assign_festival_task_path(festival, task), params: { user_id: assignee.id }
        task.reload
        expect(task.user).to eq(assignee)
      end

      it "sends notification to assignee" do
        expect {
          post assign_festival_task_path(festival, task), params: { user_id: assignee.id }
        }.to change(Notification, :count)
      end

      it "redirects to task with success message" do
        post assign_festival_task_path(festival, task), params: { user_id: assignee.id }
        expect(response).to redirect_to(festival_task_path(festival, task))
        expect(flash[:notice]).to be_present
      end
    end

    context "when user is not festival owner" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        post assign_festival_task_path(festival, task), params: { user_id: assignee.id }
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/tasks/:id/complete" do
    let(:pending_task) { create(:task, festival: festival, user: user, status: :pending) }

    it "marks the task as completed" do
      post complete_festival_task_path(festival, pending_task)
      pending_task.reload
      expect(pending_task.status).to eq("completed")
    end

    it "sends notification to festival organizers" do
      expect {
        post complete_festival_task_path(festival, pending_task)
      }.to change(Notification, :count)
    end

    it "redirects to task with success message" do
      post complete_festival_task_path(festival, pending_task)
      expect(response).to redirect_to(festival_task_path(festival, pending_task))
      expect(flash[:notice]).to be_present
    end

    context "when task is already completed" do
      let(:completed_task) { create(:task, festival: festival, user: user, status: :completed) }

      it "does not change the status" do
        post complete_festival_task_path(festival, completed_task)
        completed_task.reload
        expect(completed_task.status).to eq("completed")
      end
    end
  end

  describe "filtering and search" do
    let!(:high_priority_task) { create(:task, festival: festival, priority: :high, title: "Urgent setup") }
    let!(:low_priority_task) { create(:task, festival: festival, priority: :low, title: "Minor cleanup") }
    let!(:completed_task) { create(:task, festival: festival, status: :completed, title: "Finished work") }
    let!(:pending_task) { create(:task, festival: festival, status: :pending, title: "Pending work") }

    context "with priority filter" do
      it "filters tasks by priority" do
        get festival_tasks_path(festival), params: { priority: 'high' }
        expect(response.body).to include(high_priority_task.title)
        expect(response.body).not_to include(low_priority_task.title)
      end
    end

    context "with status filter" do
      it "filters tasks by status" do
        get festival_tasks_path(festival), params: { status: 'completed' }
        expect(response.body).to include(completed_task.title)
        expect(response.body).not_to include(pending_task.title)
      end
    end

    context "with search query" do
      it "searches tasks by title" do
        get festival_tasks_path(festival), params: { search: 'Urgent' }
        expect(response.body).to include(high_priority_task.title)
        expect(response.body).not_to include(low_priority_task.title)
      end

      it "searches tasks by description" do
        task_with_description = create(:task, festival: festival, description: "Special equipment needed")
        get festival_tasks_path(festival), params: { search: 'equipment' }
        expect(response.body).to include(task_with_description.title)
      end
    end

    context "with assignee filter" do
      let(:specific_user) { create(:user) }
      let!(:assigned_task) { create(:task, festival: festival, user: specific_user) }

      it "filters tasks by assignee" do
        get festival_tasks_path(festival), params: { assignee_id: specific_user.id }
        expect(response.body).to include(assigned_task.title)
        expect(response.body).not_to include(high_priority_task.title)
      end
    end

    context "with due date filter" do
      let!(:overdue_task) { create(:task, festival: festival, due_date: 1.day.ago, title: "Overdue task") }
      let!(:upcoming_task) { create(:task, festival: festival, due_date: 2.days.from_now, title: "Upcoming task") }

      it "filters overdue tasks" do
        get festival_tasks_path(festival), params: { filter: 'overdue' }
        expect(response.body).to include(overdue_task.title)
        expect(response.body).not_to include(upcoming_task.title)
      end

      it "filters upcoming tasks" do
        get festival_tasks_path(festival), params: { filter: 'due_soon' }
        expect(response.body).to include(upcoming_task.title)
      end
    end
  end

  describe "JSON format responses" do
    context "when requesting JSON format" do
      it "returns JSON response for index" do
        get festival_tasks_path(festival), headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to include('application/json')
      end

      it "returns JSON response for show" do
        get festival_task_path(festival, task), headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to include('application/json')
      end

      it "includes task data in JSON response" do
        get festival_task_path(festival, task), headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq(task.title)
        expect(json_response['status']).to eq(task.status)
      end

      it "includes assignee information" do
        get festival_task_path(festival, task), headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('user')
        expect(json_response['user']['id']).to eq(task.user.id)
      end
    end
  end

  describe "pagination" do
    before do
      create_list(:task, 25, festival: festival, user: user)
    end

    it "paginates tasks" do
      get festival_tasks_path(festival)
      expect(response.body).to include("Next")
    end

    it "respects per_page parameter" do
      get festival_tasks_path(festival), params: { per_page: 5 }
      # Should display 5 tasks per page
      task_count = response.body.scan(/task-item/).length
      expect(task_count).to eq(5)
    end
  end

  describe "authentication and authorization" do
    context "when user is not signed in" do
      before { sign_out user }

      it "redirects to sign in page" do
        get festival_tasks_path(festival)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when user does not have access to festival" do
      let(:other_user) { create(:user) }
      let(:private_festival) { create(:festival, public: false) }

      before { sign_in other_user }

      it "redirects to festivals index" do
        get festival_tasks_path(private_festival)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "error handling" do
    context "when festival does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get tasks_path.sub("/festivals/#{festival.id}", "/festivals/nonexistent")
        }.to raise_error(ActionController::RoutingError)
      end
    end

    context "when task does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get festival_task_path(festival, 'nonexistent')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "bulk operations" do
    let!(:task1) { create(:task, festival: festival, user: user) }
    let!(:task2) { create(:task, festival: festival, user: user) }
    let!(:task3) { create(:task, festival: festival, user: user) }

    describe "bulk complete" do
      it "completes multiple tasks" do
        patch bulk_complete_festival_tasks_path(festival), params: {
          task_ids: [ task1.id, task2.id ]
        }

        task1.reload
        task2.reload
        task3.reload

        expect(task1.status).to eq("completed")
        expect(task2.status).to eq("completed")
        expect(task3.status).not_to eq("completed")
      end

      it "redirects with success message" do
        patch bulk_complete_festival_tasks_path(festival), params: {
          task_ids: [ task1.id, task2.id ]
        }
        expect(response).to redirect_to(festival_tasks_path(festival))
        expect(flash[:notice]).to include("2 tasks completed")
      end
    end

    describe "bulk delete" do
      context "when user is festival owner" do
        it "deletes multiple tasks" do
          expect {
            delete bulk_delete_festival_tasks_path(festival), params: {
              task_ids: [ task1.id, task2.id ]
            }
          }.to change(Task, :count).by(-2)
        end
      end

      context "when user is not festival owner" do
        before { sign_in create(:user) }

        it "redirects to festivals index" do
          delete bulk_delete_festival_tasks_path(festival), params: {
            task_ids: [ task1.id, task2.id ]
          }
          expect(response).to redirect_to(festivals_path)
        end
      end
    end
  end
end
