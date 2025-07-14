require 'rails_helper'

RSpec.describe VendorApplication, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, start_date: 3.months.from_now, end_date: 4.months.from_now) }
  let(:vendor_application) { create(:vendor_application, user: user, festival: festival) }
  let(:reviewer) { create(:user, role: :admin) }

  before do
    # Skip notification callbacks for testing
    allow_any_instance_of(VendorApplication).to receive(:send_status_change_notification)
    allow_any_instance_of(VendorApplication).to receive(:create_initial_review)
  end

  describe 'associations' do
    it { should belong_to(:festival) }
    it { should belong_to(:user) }
    it { should have_many(:notifications).dependent(:destroy) }
    it { should have_many(:application_reviews).dependent(:destroy) }
    it { should have_many(:application_comments).dependent(:destroy) }
    it { should have_many(:reviewers).through(:application_reviews) }
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(VendorApplication.statuses).to eq({
        'draft' => 0,
        'submitted' => 1,
        'under_review' => 2,
        'requires_changes' => 3,
        'conditionally_approved' => 4,
        'approved' => 5,
        'rejected' => 6,
        'withdrawn' => 7,
        'cancelled' => 8
      })
    end

    it 'defines priority enum' do
      expect(VendorApplication.priorities).to eq({
        'low' => 1,
        'medium' => 2,
        'high' => 3,
        'urgent' => 4
      })
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:business_name) }
    it { should validate_presence_of(:business_type) }
    it { should validate_presence_of(:description) }
    it { should validate_length_of(:business_name).is_at_most(100) }
    it { should validate_length_of(:business_type).is_at_most(50) }
    it { should validate_length_of(:description).is_at_most(2000) }
    it { should validate_length_of(:requirements).is_at_most(1000) }

    describe 'uniqueness validation' do
      it 'validates user can only apply once per festival' do
        create(:vendor_application, user: user, festival: festival)
        duplicate_application = build(:vendor_application, user: user, festival: festival)

        expect(duplicate_application).not_to be_valid
        expect(duplicate_application.errors[:user_id]).to include('can only apply once per festival')
      end
    end
  end

  describe 'scopes' do
    let!(:submitted_app) { create(:vendor_application, status: :submitted) }
    let!(:draft_app) { create(:vendor_application, status: :draft) }
    let!(:old_app) { create(:vendor_application, created_at: 2.days.ago) }
    let!(:new_app) { create(:vendor_application, created_at: 1.day.ago) }

    describe '.by_status' do
      it 'returns applications with specified status' do
        expect(VendorApplication.by_status(:submitted)).to include(submitted_app)
        expect(VendorApplication.by_status(:submitted)).not_to include(draft_app)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        recent_apps = VendorApplication.recent.limit(2)
        expect(recent_apps.first.created_at).to be >= recent_apps.last.created_at
      end
    end
  end

  describe 'workflow state checks' do
    describe '#can_be_submitted?' do
      it 'returns true for draft status' do
        app = build(:vendor_application, status: :draft)
        expect(app.can_be_submitted?).to be true
      end

      it 'returns false for non-draft status' do
        app = build(:vendor_application, status: :submitted)
        expect(app.can_be_submitted?).to be false
      end
    end

    describe '#can_be_reviewed?' do
      it 'returns true for submitted or requires_changes status' do
        submitted_app = build(:vendor_application, status: :submitted)
        changes_app = build(:vendor_application, status: :requires_changes)

        expect(submitted_app.can_be_reviewed?).to be true
        expect(changes_app.can_be_reviewed?).to be true
      end

      it 'returns false for other statuses' do
        draft_app = build(:vendor_application, status: :draft)
        expect(draft_app.can_be_reviewed?).to be false
      end
    end

    describe '#can_be_approved?' do
      it 'returns true for reviewable statuses' do
        %i[submitted under_review requires_changes].each do |status|
          app = build(:vendor_application, status: status)
          expect(app.can_be_approved?).to be true
        end
      end
    end

    describe '#can_be_withdrawn?' do
      it 'returns true for withdrawable statuses' do
        app = build(:vendor_application, status: :submitted)
        expect(app.can_be_withdrawn?).to be true
      end

      it 'returns false for non-withdrawable statuses' do
        %i[withdrawn cancelled approved].each do |status|
          app = build(:vendor_application, status: status)
          expect(app.can_be_withdrawn?).to be false
        end
      end
    end
  end

  describe 'workflow actions' do
    describe '#submit!' do
      let(:app) { create(:vendor_application, status: :draft, festival: festival) }

      context 'when application can be submitted' do
        it 'changes status to submitted' do
          expect { app.submit!(reviewer) }.to change { app.reload.status }.to('submitted')
        end

        it 'sets submitted_at timestamp' do
          app.submit!(reviewer)
          expect(app.reload.submitted_at).to be_present
        end

        it 'sets review_deadline' do
          app.submit!(reviewer)
          expect(app.reload.review_deadline).to be_present
        end

        it 'creates application review record' do
          expect { app.submit!(reviewer) }.to change { app.application_reviews.count }.by(1)
        end
      end

      context 'when application cannot be submitted' do
        let(:app) { create(:vendor_application, status: :submitted) }

        it 'returns false and does not change status' do
          expect(app.submit!(reviewer)).to be false
          expect(app.reload.status).to eq('submitted')
        end
      end
    end

    describe '#approve!' do
      let(:app) { create(:vendor_application, status: :submitted) }

      context 'when application can be approved' do
        it 'changes status to approved' do
          expect { app.approve!(reviewer, 'Good application') }.to change { app.reload.status }.to('approved')
        end

        it 'sets reviewed_at timestamp' do
          app.approve!(reviewer, 'Good application')
          expect(app.reload.reviewed_at).to be_present
        end

        it 'creates application review record' do
          expect { app.approve!(reviewer, 'Good application') }.to change { app.application_reviews.count }.by(1)
        end
      end

      context 'when application cannot be approved' do
        let(:app) { create(:vendor_application, status: :approved) }

        it 'returns false and does not change status' do
          expect(app.approve!(reviewer, 'Comment')).to be false
          expect(app.reload.status).to eq('approved')
        end
      end
    end

    describe '#reject!' do
      let(:app) { create(:vendor_application, status: :submitted) }

      context 'when application can be rejected with comment' do
        it 'changes status to rejected' do
          expect { app.reject!(reviewer, 'Not suitable') }.to change { app.reload.status }.to('rejected')
        end

        it 'creates application review record with comment' do
          app.reject!(reviewer, 'Not suitable')
          review = app.application_reviews.last
          expect(review.comment).to eq('Not suitable')
        end
      end

      context 'when comment is blank' do
        it 'returns false and does not change status' do
          expect(app.reject!(reviewer, '')).to be false
          expect(app.reload.status).to eq('submitted')
        end
      end
    end

    describe '#request_changes!' do
      let(:app) { create(:vendor_application, status: :submitted) }

      context 'when changes can be requested with comment' do
        it 'changes status to requires_changes' do
          expect { app.request_changes!(reviewer, 'Please add more details') }.to change { app.reload.status }.to('requires_changes')
        end
      end

      context 'when comment is blank' do
        it 'returns false and does not change status' do
          expect(app.request_changes!(reviewer, '')).to be false
          expect(app.reload.status).to eq('submitted')
        end
      end
    end
  end

  describe 'status display methods' do
    describe '#status_text' do
      it 'returns Japanese status text' do
        app = build(:vendor_application, status: :draft)
        expect(app.status_text).to eq('下書き')

        app.status = :approved
        expect(app.status_text).to eq('承認')
      end
    end

    describe '#status_color' do
      it 'returns appropriate Bootstrap color class' do
        app = build(:vendor_application, status: :approved)
        expect(app.status_color).to eq('success')

        app.status = :rejected
        expect(app.status_color).to eq('danger')
      end
    end

    describe '#priority_text' do
      it 'returns Japanese priority text' do
        app = build(:vendor_application, priority: :high)
        expect(app.priority_text).to eq('高')

        app.priority = :low
        expect(app.priority_text).to eq('低')
      end
    end
  end

  describe 'deadline management' do
    describe '#submission_overdue?' do
      it 'returns true when past submission deadline and not submitted' do
        app = build(:vendor_application, status: :draft, submission_deadline: 1.day.ago)
        expect(app.submission_overdue?).to be true
      end

      it 'returns false when submitted' do
        app = build(:vendor_application, status: :submitted, submission_deadline: 1.day.ago)
        expect(app.submission_overdue?).to be false
      end
    end

    describe '#review_overdue?' do
      it 'returns true when past review deadline and not reviewed' do
        app = build(:vendor_application, status: :submitted, review_deadline: 1.day.ago)
        expect(app.review_overdue?).to be true
      end

      it 'returns false when reviewed' do
        app = build(:vendor_application, status: :approved, review_deadline: 1.day.ago)
        expect(app.review_overdue?).to be false
      end
    end

    describe '#reviewed?' do
      it 'returns true for final statuses' do
        %i[approved rejected withdrawn cancelled].each do |status|
          app = build(:vendor_application, status: status)
          expect(app.reviewed?).to be true
        end
      end

      it 'returns false for non-final statuses' do
        %i[draft submitted under_review requires_changes].each do |status|
          app = build(:vendor_application, status: status)
          expect(app.reviewed?).to be false
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      context 'when status is not draft' do
        it 'creates initial review' do
          app = build(:vendor_application, status: :submitted, user: user, festival: festival)
          expect { app.save! }.to change { ApplicationReview.count }.by(1)
        end
      end

      context 'when status is draft' do
        it 'does not create initial review' do
          app = build(:vendor_application, status: :draft, user: user, festival: festival)
          expect { app.save! }.not_to change { ApplicationReview.count }
        end
      end
    end

    describe 'after_update' do
      let(:app) { create(:vendor_application, status: :submitted) }

      it 'sends notification when status changes' do
        expect(NotificationService).to receive(:send_vendor_application_status_notification)
        app.update!(status: :approved)
      end

      it 'does not send notification when status does not change' do
        expect(NotificationService).not_to receive(:send_vendor_application_status_notification)
        app.update!(business_name: 'Updated Name')
      end
    end
  end

  describe 'Active Storage attachments' do
    it 'can have many documents' do
      expect(vendor_application).to respond_to(:documents)
    end

    it 'can have many business_documents' do
      expect(vendor_application).to respond_to(:business_documents)
    end

    it 'can have one business_license' do
      expect(vendor_application).to respond_to(:business_license)
    end
  end
end
