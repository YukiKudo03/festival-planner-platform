require 'rails_helper'

RSpec.describe NotificationSetting, type: :model do
  let(:user) { create(:user) }
  let(:notification_setting) { create(:notification_setting, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'constants' do
    it 'defines FREQUENCIES constant' do
      expect(NotificationSetting::FREQUENCIES).to eq(%w[immediate daily weekly never])
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:notification_type) }
    it { should validate_inclusion_of(:frequency).in_array(%w[immediate daily weekly never]) }

    describe 'notification_type inclusion validation' do
      it 'validates notification_type is in NOTIFICATION_TYPES' do
        setting = build(:notification_setting, notification_type: 'invalid_type')
        expect(setting).not_to be_valid
        expect(setting.errors[:notification_type]).to include('is not included in the list')
      end

      it 'allows valid notification types' do
        Notification::NOTIFICATION_TYPES.each do |type|
          setting = build(:notification_setting, notification_type: type)
          expect(setting).to be_valid
        end
      end
    end

    describe 'uniqueness validation' do
      it 'validates user can only have one setting per notification type' do
        create(:notification_setting, user: user, notification_type: 'task_assigned')
        duplicate_setting = build(:notification_setting, user: user, notification_type: 'task_assigned')
        
        expect(duplicate_setting).not_to be_valid
        expect(duplicate_setting.errors[:user_id]).to include('has already been taken')
      end
    end
  end

  describe 'scopes' do
    let!(:email_enabled) { create(:notification_setting, email_enabled: true) }
    let!(:email_disabled) { create(:notification_setting, email_enabled: false) }
    let!(:web_enabled) { create(:notification_setting, web_enabled: true) }
    let!(:web_disabled) { create(:notification_setting, web_enabled: false) }
    let!(:immediate) { create(:notification_setting, frequency: 'immediate') }
    let!(:daily) { create(:notification_setting, frequency: 'daily') }
    let!(:task_assigned) { create(:notification_setting, notification_type: 'task_assigned') }

    describe '.enabled_for_email' do
      it 'returns settings with email enabled' do
        expect(NotificationSetting.enabled_for_email).to include(email_enabled)
        expect(NotificationSetting.enabled_for_email).not_to include(email_disabled)
      end
    end

    describe '.enabled_for_web' do
      it 'returns settings with web enabled' do
        expect(NotificationSetting.enabled_for_web).to include(web_enabled)
        expect(NotificationSetting.enabled_for_web).not_to include(web_disabled)
      end
    end

    describe '.by_type' do
      it 'returns settings with specified notification type' do
        expect(NotificationSetting.by_type('task_assigned')).to include(task_assigned)
      end
    end

    describe '.by_frequency' do
      it 'returns settings with specified frequency' do
        expect(NotificationSetting.by_frequency('immediate')).to include(immediate)
        expect(NotificationSetting.by_frequency('daily')).to include(daily)
      end
    end
  end

  describe 'class methods' do
    describe '.default_settings_for_user' do
      it 'returns default settings for all notification types' do
        defaults = NotificationSetting.default_settings_for_user(user)
        
        expect(defaults.length).to eq(Notification::NOTIFICATION_TYPES.length)
        expect(defaults.first[:user]).to eq(user)
        expect(defaults.first[:email_enabled]).to be true
        expect(defaults.first[:web_enabled]).to be true
        expect(defaults.first[:frequency]).to eq('immediate')
      end

      it 'includes all notification types' do
        defaults = NotificationSetting.default_settings_for_user(user)
        notification_types = defaults.map { |setting| setting[:notification_type] }
        
        expect(notification_types).to match_array(Notification::NOTIFICATION_TYPES)
      end
    end

    describe '.create_defaults_for_user' do
      it 'creates default settings for new user' do
        new_user = create(:user)
        
        expect {
          NotificationSetting.create_defaults_for_user(new_user)
        }.to change { new_user.notification_settings.count }.by(Notification::NOTIFICATION_TYPES.length)
      end

      it 'does not create duplicates for existing settings' do
        existing_setting = create(:notification_setting, user: user, notification_type: 'task_assigned')
        
        expect {
          NotificationSetting.create_defaults_for_user(user)
        }.to change { user.notification_settings.count }.by(Notification::NOTIFICATION_TYPES.length - 1)
        
        # Existing setting should remain unchanged
        expect(existing_setting.reload).to eq(existing_setting)
      end

      it 'sets correct default values for new settings' do
        new_user = create(:user)
        NotificationSetting.create_defaults_for_user(new_user)
        
        settings = new_user.notification_settings
        expect(settings.all?(&:email_enabled?)).to be true
        expect(settings.all?(&:web_enabled?)).to be true
        expect(settings.all? { |s| s.frequency == 'immediate' }).to be true
      end
    end
  end

  describe 'instance methods' do
    describe '#should_send_email?' do
      context 'when email is enabled and frequency is not never' do
        let(:setting) { build(:notification_setting, email_enabled: true, frequency: 'immediate') }

        it 'returns true' do
          expect(setting.should_send_email?).to be true
        end
      end

      context 'when email is disabled' do
        let(:setting) { build(:notification_setting, email_enabled: false, frequency: 'immediate') }

        it 'returns false' do
          expect(setting.should_send_email?).to be false
        end
      end

      context 'when frequency is never' do
        let(:setting) { build(:notification_setting, email_enabled: true, frequency: 'never') }

        it 'returns false' do
          expect(setting.should_send_email?).to be false
        end
      end
    end

    describe '#should_send_web?' do
      context 'when web is enabled and frequency is not never' do
        let(:setting) { build(:notification_setting, web_enabled: true, frequency: 'daily') }

        it 'returns true' do
          expect(setting.should_send_web?).to be true
        end
      end

      context 'when web is disabled' do
        let(:setting) { build(:notification_setting, web_enabled: false, frequency: 'immediate') }

        it 'returns false' do
          expect(setting.should_send_web?).to be false
        end
      end

      context 'when frequency is never' do
        let(:setting) { build(:notification_setting, web_enabled: true, frequency: 'never') }

        it 'returns false' do
          expect(setting.should_send_web?).to be false
        end
      end
    end

    describe '#should_send_immediately?' do
      context 'when frequency is immediate' do
        let(:setting) { build(:notification_setting, frequency: 'immediate') }

        it 'returns true' do
          expect(setting.should_send_immediately?).to be true
        end
      end

      context 'when frequency is not immediate' do
        %w[daily weekly never].each do |frequency|
          let(:setting) { build(:notification_setting, frequency: frequency) }

          it "returns false for #{frequency}" do
            expect(setting.should_send_immediately?).to be false
          end
        end
      end
    end
  end

  describe 'integration with User model' do
    it 'is accessible through user association' do
      user = create(:user)
      setting = create(:notification_setting, user: user)
      
      expect(user.notification_settings).to include(setting)
    end
  end
end