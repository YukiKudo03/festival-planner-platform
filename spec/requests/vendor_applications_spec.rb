require 'rails_helper'

RSpec.describe "VendorApplications", type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, role: :admin) }
  let(:committee_member) { create(:user, role: :committee_member) }
  let(:festival) { create(:festival, user: user) }
  let(:vendor_application) { create(:vendor_application, festival: festival, user: user) }
  let(:other_application) { create(:vendor_application) }

  before { sign_in user }

  describe "GET /festivals/:festival_id/vendor_applications" do
    let!(:festival_application) { create(:vendor_application, festival: festival, user: user) }
    let!(:other_user_application) { create(:vendor_application, festival: festival) }

    it "returns a successful response" do
      get festival_vendor_applications_path(festival)
      expect(response).to be_successful
    end

    it "displays user's vendor applications" do
      get festival_vendor_applications_path(festival)
      expect(response.body).to include(festival_application.business_name)
    end

    context "when user is festival owner" do
      it "displays all applications for the festival" do
        get festival_vendor_applications_path(festival)
        expect(response.body).to include(festival_application.business_name)
        expect(response.body).to include(other_user_application.business_name)
      end
    end

    context "when user is not festival participant" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get festival_vendor_applications_path(festival)
        expect(response).to redirect_to(festivals_path)
      end
    end

    context "with admin user" do
      before { sign_in admin }

      it "allows access to any festival's applications" do
        get festival_vendor_applications_path(festival)
        expect(response).to be_successful
      end
    end
  end

  describe "GET /festivals/:festival_id/vendor_applications/:id" do
    it "returns a successful response" do
      get festival_vendor_application_path(festival, vendor_application)
      expect(response).to be_successful
    end

    it "assigns the vendor application" do
      get festival_vendor_application_path(festival, vendor_application)
      expect(response.body).to include(vendor_application.business_name)
    end

    context "when application belongs to different festival" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get festival_vendor_application_path(festival, other_application)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when user is not application owner and not festival owner" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get festival_vendor_application_path(festival, vendor_application)
        expect(response).to redirect_to(festivals_path)
      end
    end

    context "when user is festival owner but not application owner" do
      let(:other_user_application) { create(:vendor_application, festival: festival) }

      it "allows access" do
        get festival_vendor_application_path(festival, other_user_application)
        expect(response).to be_successful
      end
    end
  end

  describe "GET /festivals/:festival_id/vendor_applications/new" do
    it "returns a successful response" do
      get new_festival_vendor_application_path(festival)
      expect(response).to be_successful
    end

    it "renders the new vendor application form" do
      get new_festival_vendor_application_path(festival)
      expect(response.body).to include("New Vendor Application")
    end

    context "when user already has an application for this festival" do
      let!(:existing_application) { create(:vendor_application, festival: festival, user: user) }

      it "redirects to existing application" do
        get new_festival_vendor_application_path(festival)
        expect(response).to redirect_to(festival_vendor_application_path(festival, existing_application))
      end

      it "sets a flash message" do
        get new_festival_vendor_application_path(festival)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user cannot access festival" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        get new_festival_vendor_application_path(festival)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/vendor_applications" do
    let(:valid_attributes) do
      {
        business_name: "Amazing Food Truck",
        business_type: "Food & Beverage",
        description: "We serve delicious local cuisine with fresh ingredients",
        requirements: "Need electrical hookup and water access"
      }
    end

    let(:invalid_attributes) do
      {
        business_name: "",
        business_type: "",
        description: ""
      }
    end

    context "with valid parameters" do
      it "creates a new vendor application" do
        expect {
          post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        }.to change(VendorApplication, :count).by(1)
      end

      it "assigns the application to the current user" do
        post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        expect(VendorApplication.last.user).to eq(user)
      end

      it "assigns the application to the festival" do
        post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        expect(VendorApplication.last.festival).to eq(festival)
      end

      it "sets status to draft by default" do
        post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        expect(VendorApplication.last.status).to eq("draft")
      end

      it "redirects to the created application" do
        post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        expect(response).to redirect_to(festival_vendor_application_path(festival, VendorApplication.last))
      end

      it "sets a success flash message" do
        post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      it "does not create a vendor application" do
        expect {
          post festival_vendor_applications_path(festival), params: { vendor_application: invalid_attributes }
        }.not_to change(VendorApplication, :count)
      end

      it "renders the new template" do
        post festival_vendor_applications_path(festival), params: { vendor_application: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it "returns unprocessable entity status" do
        post festival_vendor_applications_path(festival), params: { vendor_application: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when user already has an application" do
      let!(:existing_application) { create(:vendor_application, festival: festival, user: user) }

      it "does not create another application" do
        expect {
          post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        }.not_to change(VendorApplication, :count)
      end

      it "redirects to existing application" do
        post festival_vendor_applications_path(festival), params: { vendor_application: valid_attributes }
        expect(response).to redirect_to(festival_vendor_application_path(festival, existing_application))
      end
    end

    context "with file attachments" do
      let(:attributes_with_files) do
        valid_attributes.merge(
          business_documents: [
            fixture_file_upload('spec/fixtures/test_document.pdf', 'application/pdf')
          ],
          business_license: fixture_file_upload('spec/fixtures/test_license.pdf', 'application/pdf')
        )
      end

      it "attaches files to the application" do
        post festival_vendor_applications_path(festival), params: { vendor_application: attributes_with_files }
        application = VendorApplication.last
        expect(application.business_documents).to be_attached
        expect(application.business_license).to be_attached
      end
    end
  end

  describe "PATCH /festivals/:festival_id/vendor_applications/:id" do
    let(:new_attributes) do
      {
        business_name: "Updated Business Name",
        description: "Updated business description",
        requirements: "Updated requirements"
      }
    end

    context "with valid parameters" do
      it "updates the vendor application" do
        patch festival_vendor_application_path(festival, vendor_application), params: { vendor_application: new_attributes }
        vendor_application.reload
        expect(vendor_application.business_name).to eq("Updated Business Name")
      end

      it "redirects to the application" do
        patch festival_vendor_application_path(festival, vendor_application), params: { vendor_application: new_attributes }
        expect(response).to redirect_to(festival_vendor_application_path(festival, vendor_application))
      end

      it "sets a success flash message" do
        patch festival_vendor_application_path(festival, vendor_application), params: { vendor_application: new_attributes }
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) { { business_name: "", description: "" } }

      it "does not update the application" do
        original_name = vendor_application.business_name
        patch festival_vendor_application_path(festival, vendor_application), params: { vendor_application: invalid_attributes }
        vendor_application.reload
        expect(vendor_application.business_name).to eq(original_name)
      end

      it "renders the edit template" do
        patch festival_vendor_application_path(festival, vendor_application), params: { vendor_application: invalid_attributes }
        expect(response).to render_template(:edit)
      end
    end

    context "when application is submitted" do
      let(:submitted_application) { create(:vendor_application, festival: festival, user: user, status: :submitted) }

      it "does not allow updates to submitted applications" do
        patch festival_vendor_application_path(festival, submitted_application), params: { vendor_application: new_attributes }
        expect(response).to redirect_to(festival_vendor_application_path(festival, submitted_application))
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not application owner" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        patch festival_vendor_application_path(festival, vendor_application), params: { vendor_application: new_attributes }
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "DELETE /festivals/:festival_id/vendor_applications/:id" do
    let!(:application_to_delete) { create(:vendor_application, festival: festival, user: user, status: :draft) }

    context "when application is in draft status" do
      it "destroys the application" do
        expect {
          delete festival_vendor_application_path(festival, application_to_delete)
        }.to change(VendorApplication, :count).by(-1)
      end

      it "redirects to applications index" do
        delete festival_vendor_application_path(festival, application_to_delete)
        expect(response).to redirect_to(festival_vendor_applications_path(festival))
      end

      it "sets a success flash message" do
        delete festival_vendor_application_path(festival, application_to_delete)
        expect(flash[:notice]).to be_present
      end
    end

    context "when application is submitted" do
      let(:submitted_application) { create(:vendor_application, festival: festival, user: user, status: :submitted) }

      it "does not destroy the application" do
        expect {
          delete festival_vendor_application_path(festival, submitted_application)
        }.not_to change(VendorApplication, :count)
      end

      it "redirects with error message" do
        delete festival_vendor_application_path(festival, submitted_application)
        expect(response).to redirect_to(festival_vendor_application_path(festival, submitted_application))
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not application owner" do
      before { sign_in create(:user) }

      it "redirects to festivals index" do
        delete festival_vendor_application_path(festival, application_to_delete)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "POST /festivals/:festival_id/vendor_applications/:id/submit" do
    let(:draft_application) { create(:vendor_application, festival: festival, user: user, status: :draft) }

    it "submits the application" do
      post submit_festival_vendor_application_path(festival, draft_application)
      draft_application.reload
      expect(draft_application.status).to eq("submitted")
    end

    it "sets submission timestamp" do
      post submit_festival_vendor_application_path(festival, draft_application)
      draft_application.reload
      expect(draft_application.submitted_at).to be_present
    end

    it "creates initial review record" do
      expect {
        post submit_festival_vendor_application_path(festival, draft_application)
      }.to change(ApplicationReview, :count).by(1)
    end

    it "sends notification to festival organizers" do
      expect {
        post submit_festival_vendor_application_path(festival, draft_application)
      }.to change(Notification, :count)
    end

    it "redirects to application with success message" do
      post submit_festival_vendor_application_path(festival, draft_application)
      expect(response).to redirect_to(festival_vendor_application_path(festival, draft_application))
      expect(flash[:notice]).to be_present
    end

    context "when application is already submitted" do
      let(:submitted_application) { create(:vendor_application, festival: festival, user: user, status: :submitted) }

      it "does not change the status" do
        post submit_festival_vendor_application_path(festival, submitted_application)
        submitted_application.reload
        expect(submitted_application.status).to eq("submitted")
      end
    end

    context "when application is incomplete" do
      let(:incomplete_application) { create(:vendor_application, festival: festival, user: user, business_name: "") }

      it "does not submit the application" do
        post submit_festival_vendor_application_path(festival, incomplete_application)
        incomplete_application.reload
        expect(incomplete_application.status).not_to eq("submitted")
      end

      it "redirects with error message" do
        post submit_festival_vendor_application_path(festival, incomplete_application)
        expect(response).to redirect_to(festival_vendor_application_path(festival, incomplete_application))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "POST /festivals/:festival_id/vendor_applications/:id/withdraw" do
    let(:submitted_application) { create(:vendor_application, festival: festival, user: user, status: :submitted) }

    it "withdraws the application" do
      post withdraw_festival_vendor_application_path(festival, submitted_application)
      submitted_application.reload
      expect(submitted_application.status).to eq("withdrawn")
    end

    it "creates withdrawal review record" do
      expect {
        post withdraw_festival_vendor_application_path(festival, submitted_application)
      }.to change(ApplicationReview, :count).by(1)
    end

    it "redirects to application with success message" do
      post withdraw_festival_vendor_application_path(festival, submitted_application)
      expect(response).to redirect_to(festival_vendor_application_path(festival, submitted_application))
      expect(flash[:notice]).to be_present
    end

    context "when application is approved" do
      let(:approved_application) { create(:vendor_application, festival: festival, user: user, status: :approved) }

      it "does not allow withdrawal" do
        post withdraw_festival_vendor_application_path(festival, approved_application)
        approved_application.reload
        expect(approved_application.status).to eq("approved")
      end
    end
  end

  describe "admin/reviewer actions" do
    let(:submitted_application) { create(:vendor_application, festival: festival, status: :submitted) }

    describe "POST /festivals/:festival_id/vendor_applications/:id/start_review" do
      context "when user is committee member" do
        before { sign_in committee_member }

        it "starts review process" do
          post start_review_festival_vendor_application_path(festival, submitted_application)
          submitted_application.reload
          expect(submitted_application.status).to eq("under_review")
        end

        it "creates review record" do
          expect {
            post start_review_festival_vendor_application_path(festival, submitted_application)
          }.to change(ApplicationReview, :count).by(1)
        end

        it "redirects to application with success message" do
          post start_review_festival_vendor_application_path(festival, submitted_application)
          expect(response).to redirect_to(festival_vendor_application_path(festival, submitted_application))
          expect(flash[:notice]).to be_present
        end
      end

      context "when user is not authorized" do
        it "redirects to festivals index" do
          post start_review_festival_vendor_application_path(festival, submitted_application)
          expect(response).to redirect_to(festivals_path)
        end
      end
    end

    describe "POST /festivals/:festival_id/vendor_applications/:id/approve" do
      context "when user is admin" do
        before { sign_in admin }

        it "approves the application" do
          post approve_festival_vendor_application_path(festival, submitted_application), params: {
            comment: "Application meets all requirements"
          }
          submitted_application.reload
          expect(submitted_application.status).to eq("approved")
        end

        it "sets reviewed timestamp" do
          post approve_festival_vendor_application_path(festival, submitted_application), params: {
            comment: "Application approved"
          }
          submitted_application.reload
          expect(submitted_application.reviewed_at).to be_present
        end

        it "creates approval review record" do
          expect {
            post approve_festival_vendor_application_path(festival, submitted_application), params: {
              comment: "Application approved"
            }
          }.to change(ApplicationReview, :count).by(1)
        end

        it "sends notification to applicant" do
          expect {
            post approve_festival_vendor_application_path(festival, submitted_application), params: {
              comment: "Application approved"
            }
          }.to change(Notification, :count)
        end
      end

      context "when user is not admin" do
        it "redirects to festivals index" do
          post approve_festival_vendor_application_path(festival, submitted_application), params: {
            comment: "Application approved"
          }
          expect(response).to redirect_to(festivals_path)
        end
      end
    end

    describe "POST /festivals/:festival_id/vendor_applications/:id/reject" do
      context "when user is admin" do
        before { sign_in admin }

        it "rejects the application" do
          post reject_festival_vendor_application_path(festival, submitted_application), params: {
            comment: "Application does not meet requirements"
          }
          submitted_application.reload
          expect(submitted_application.status).to eq("rejected")
        end

        it "requires a comment" do
          post reject_festival_vendor_application_path(festival, submitted_application)
          submitted_application.reload
          expect(submitted_application.status).not_to eq("rejected")
          expect(flash[:alert]).to be_present
        end

        it "creates rejection review record" do
          expect {
            post reject_festival_vendor_application_path(festival, submitted_application), params: {
              comment: "Application rejected"
            }
          }.to change(ApplicationReview, :count).by(1)
        end
      end
    end

    describe "POST /festivals/:festival_id/vendor_applications/:id/request_changes" do
      context "when user is committee member" do
        before { sign_in committee_member }

        it "requests changes to the application" do
          post request_changes_festival_vendor_application_path(festival, submitted_application), params: {
            comment: "Please provide additional documentation"
          }
          submitted_application.reload
          expect(submitted_application.status).to eq("requires_changes")
        end

        it "requires a comment" do
          post request_changes_festival_vendor_application_path(festival, submitted_application)
          submitted_application.reload
          expect(submitted_application.status).not_to eq("requires_changes")
          expect(flash[:alert]).to be_present
        end
      end
    end
  end

  describe "filtering and search" do
    let!(:food_application) { create(:vendor_application, festival: festival, business_type: "Food", business_name: "Great Food Co") }
    let!(:craft_application) { create(:vendor_application, festival: festival, business_type: "Crafts", business_name: "Artisan Crafts") }
    let!(:approved_application) { create(:vendor_application, festival: festival, status: :approved) }
    let!(:pending_application) { create(:vendor_application, festival: festival, status: :under_review) }

    before { sign_in festival.user } # Festival owner to see all applications

    context "with business type filter" do
      it "filters applications by business type" do
        get festival_vendor_applications_path(festival), params: { business_type: 'Food' }
        expect(response.body).to include(food_application.business_name)
        expect(response.body).not_to include(craft_application.business_name)
      end
    end

    context "with status filter" do
      it "filters applications by status" do
        get festival_vendor_applications_path(festival), params: { status: 'approved' }
        expect(response.body).to include(approved_application.business_name)
        expect(response.body).not_to include(pending_application.business_name)
      end
    end

    context "with search query" do
      it "searches applications by business name" do
        get festival_vendor_applications_path(festival), params: { search: 'Great Food' }
        expect(response.body).to include(food_application.business_name)
        expect(response.body).not_to include(craft_application.business_name)
      end

      it "searches applications by description" do
        description_application = create(:vendor_application, festival: festival, description: "Specialized organic products")
        get festival_vendor_applications_path(festival), params: { search: 'organic' }
        expect(response.body).to include(description_application.business_name)
      end
    end
  end

  describe "JSON format responses" do
    context "when requesting JSON format" do
      it "returns JSON response for index" do
        get festival_vendor_applications_path(festival), headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to include('application/json')
      end

      it "returns JSON response for show" do
        get festival_vendor_application_path(festival, vendor_application), headers: { 'Accept' => 'application/json' }
        expect(response.content_type).to include('application/json')
      end

      it "includes application data in JSON response" do
        get festival_vendor_application_path(festival, vendor_application), headers: { 'Accept' => 'application/json' }
        json_response = JSON.parse(response.body)
        expect(json_response['business_name']).to eq(vendor_application.business_name)
        expect(json_response['status']).to eq(vendor_application.status)
      end
    end
  end

  describe "pagination" do
    before do
      sign_in festival.user # Festival owner to see all applications
      create_list(:vendor_application, 15, festival: festival)
    end

    it "paginates applications" do
      get festival_vendor_applications_path(festival)
      expect(response.body).to include("Next")
    end
  end

  describe "authentication and authorization" do
    context "when user is not signed in" do
      before { sign_out user }

      it "redirects to sign in page" do
        get festival_vendor_applications_path(festival)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when festival is private and user is not participant" do
      let(:other_user) { create(:user) }
      let(:private_festival) { create(:festival, public: false) }

      before { sign_in other_user }

      it "redirects to festivals index" do
        get festival_vendor_applications_path(private_festival)
        expect(response).to redirect_to(festivals_path)
      end
    end
  end

  describe "error handling" do
    context "when festival does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get vendor_applications_path.sub("/festivals/#{festival.id}", "/festivals/nonexistent")
        }.to raise_error(ActionController::RoutingError)
      end
    end

    context "when vendor application does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get festival_vendor_application_path(festival, 'nonexistent')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
