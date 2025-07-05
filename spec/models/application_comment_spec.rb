require 'rails_helper'

RSpec.describe ApplicationComment, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_length_of(:content).is_at_most(1000) }
  end

  describe 'associations' do
    it { should belong_to(:vendor_application) }
    it { should belong_to(:user) }
  end

  describe 'scopes' do
    let(:vendor_application) { create(:vendor_application) }
    let!(:public_comment) { create(:application_comment, vendor_application: vendor_application, internal: false) }
    let!(:internal_comment) { create(:application_comment, vendor_application: vendor_application, internal: true) }

    describe '.public_comments' do
      it 'returns only public comments' do
        expect(ApplicationComment.public_comments).to include(public_comment)
        expect(ApplicationComment.public_comments).not_to include(internal_comment)
      end
    end

    describe '.internal_comments' do
      it 'returns only internal comments' do
        expect(ApplicationComment.internal_comments).to include(internal_comment)
        expect(ApplicationComment.internal_comments).not_to include(public_comment)
      end
    end

    describe '.recent' do
      it 'orders comments by created_at desc' do
        # Clear any existing comments first
        ApplicationComment.destroy_all
        
        older_comment = create(:application_comment, vendor_application: vendor_application, created_at: 1.day.ago)
        newer_comment = create(:application_comment, vendor_application: vendor_application, created_at: 1.hour.ago)
        
        recent_comments = ApplicationComment.recent
        expect(recent_comments.first).to eq(newer_comment)
        expect(recent_comments.last).to eq(older_comment)
      end
    end
  end

  describe 'instance methods' do
    let(:comment) { create(:application_comment, internal: false) }

    describe '#visibility_text' do
      it 'returns visibility text' do
        expect(comment.visibility_text).to eq('公開コメント')
      end
    end

    describe '#can_be_seen_by?' do
      let(:admin) { create(:user, :admin) }
      let(:regular_user) { create(:user) }

      context 'when comment is public' do
        it 'can be seen by anyone' do
          expect(comment.can_be_seen_by?(regular_user)).to be true
        end
      end

      context 'when comment is internal' do
        let(:internal_comment) { create(:application_comment, internal: true) }

        it 'can be seen by admin' do
          expect(internal_comment.can_be_seen_by?(admin)).to be true
        end

        it 'cannot be seen by regular user' do
          expect(internal_comment.can_be_seen_by?(regular_user)).to be false
        end
      end
    end
  end
end
