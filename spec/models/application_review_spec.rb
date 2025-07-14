require 'rails_helper'

RSpec.describe ApplicationReview, type: :model do
  describe 'validations' do
    subject { build(:application_review, action: :started_review) }

    it 'validates reviewed_at for non-submitted actions' do
      review = build(:application_review, action: :started_review, reviewed_at: nil)
      expect(review).to be_invalid
      expect(review.errors[:reviewed_at]).to include("can't be blank")
    end

    it 'does not validate reviewed_at for submitted action' do
      review = build(:application_review, action: :submitted, reviewed_at: nil)
      expect(review).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:vendor_application) }
    it { should belong_to(:reviewer).class_name('User') }
  end

  describe 'enums' do
    it { should define_enum_for(:action).with_values(
      submitted: 0,
      started_review: 1,
      requested_changes: 2,
      conditionally_approved: 3,
      approved: 4,
      rejected: 5,
      withdrawn: 6
    ) }
  end

  describe 'scopes' do
    let(:vendor_application) { create(:vendor_application) }
    let!(:old_review) { create(:application_review, vendor_application: vendor_application, reviewed_at: 1.week.ago) }
    let!(:recent_review) { create(:application_review, vendor_application: vendor_application, reviewed_at: 1.day.ago) }

    describe '.recent' do
      it 'orders reviews by reviewed_at desc' do
        expect(ApplicationReview.recent.first).to eq(recent_review)
        expect(ApplicationReview.recent.last).to eq(old_review)
      end
    end

    describe '.by_action' do
      let!(:approved_review) { create(:application_review, vendor_application: vendor_application, action: :approved) }
      let!(:rejected_review) { create(:application_review, vendor_application: vendor_application, action: :rejected) }

      it 'filters reviews by action' do
        expect(ApplicationReview.by_action(:approved)).to include(approved_review)
        expect(ApplicationReview.by_action(:approved)).not_to include(rejected_review)
      end
    end
  end

  describe 'instance methods' do
    let(:review) { create(:application_review, action: :approved) }

    describe '#action_text' do
      it 'returns Japanese text for action' do
        expect(review.action_text).to eq('承認')
      end
    end
  end
end
