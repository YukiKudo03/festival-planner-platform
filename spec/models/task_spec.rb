require 'rails_helper'

RSpec.describe Task, type: :model do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user, start_date: 1.month.from_now, end_date: 2.months.from_now) }
  let(:task) { create(:task, user: user, festival: festival) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:festival) }
    it { should have_many(:notifications).dependent(:destroy) }
  end

  describe 'enums' do
    it 'defines priority enum' do
      expect(Task.priorities).to eq({
        'low' => 0,
        'medium' => 1,
        'high' => 2,
        'urgent' => 3
      })
    end

    it 'defines status enum' do
      expect(Task.statuses).to eq({
        'pending' => 0,
        'in_progress' => 1,
        'completed' => 2,
        'cancelled' => 3
      })
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:due_date) }
    it { should validate_length_of(:title).is_at_most(200) }
    it { should validate_length_of(:description).is_at_most(1000) }

    describe 'due_date_within_festival_period' do
      context 'when due_date is within reasonable festival period' do
        it 'is valid' do
          task = build(:task, user: user, festival: festival, due_date: 1.week.from_now)
          expect(task).to be_valid
        end
      end

      context 'when due_date is too early' do
        it 'is invalid' do
          task = build(:task, user: user, festival: festival, due_date: 1.year.ago)
          expect(task).not_to be_valid
          expect(task.errors[:due_date]).to include('should be within reasonable festival planning period')
        end
      end

      context 'when due_date is too late' do
        it 'is invalid' do
          task = build(:task, user: user, festival: festival, due_date: 1.year.from_now)
          expect(task).not_to be_valid
          expect(task.errors[:due_date]).to include('should be within reasonable festival planning period')
        end
      end
    end
  end

  describe 'scopes' do
    let!(:overdue_task) { create(:task, due_date: 1.day.ago, status: :pending) }
    let!(:due_soon_task) { create(:task, due_date: 1.day.from_now, status: :pending) }
    let!(:completed_task) { create(:task, due_date: 1.day.ago, status: :completed) }

    describe '.overdue' do
      it 'returns overdue pending tasks' do
        expect(Task.overdue).to include(overdue_task)
        expect(Task.overdue).not_to include(completed_task)
        expect(Task.overdue).not_to include(due_soon_task)
      end
    end

    describe '.due_soon' do
      it 'returns tasks due within 3 days and not completed' do
        expect(Task.due_soon).to include(due_soon_task)
        expect(Task.due_soon).not_to include(overdue_task)
        expect(Task.due_soon).not_to include(completed_task)
      end
    end

    describe '.by_priority' do
      let!(:high_priority) { create(:task, priority: :high) }
      let!(:low_priority) { create(:task, priority: :low) }

      it 'orders by priority' do
        priorities = Task.by_priority.pluck(:priority)
        expect(priorities).to include('low', 'high')
        expect(priorities.index('low')).to be < priorities.index('high')
      end
    end

    describe '.by_due_date' do
      let!(:later_task) { create(:task, due_date: 2.days.from_now) }
      let!(:earlier_task) { create(:task, due_date: 1.day.from_now) }

      it 'orders by due_date' do
        tasks = Task.by_due_date.limit(2)
        expect(tasks.first.due_date).to be <= tasks.last.due_date
      end
    end
  end

  describe 'instance methods' do
    describe '#overdue?' do
      context 'when task is overdue and not completed' do
        let(:task) { create(:task, due_date: 1.day.ago, status: :pending) }

        it 'returns true' do
          expect(task.overdue?).to be true
        end
      end

      context 'when task is overdue but completed' do
        let(:task) { create(:task, due_date: 1.day.ago, status: :completed) }

        it 'returns false' do
          expect(task.overdue?).to be false
        end
      end

      context 'when task is not overdue' do
        let(:task) { create(:task, due_date: 1.day.from_now, status: :pending) }

        it 'returns false' do
          expect(task.overdue?).to be false
        end
      end
    end

    describe '#due_soon?' do
      context 'when task is due within 3 days and not completed' do
        let(:task) { create(:task, due_date: 2.days.from_now, status: :pending) }

        it 'returns true' do
          expect(task.due_soon?).to be true
        end
      end

      context 'when task is due within 3 days but completed' do
        let(:task) { create(:task, due_date: 2.days.from_now, status: :completed) }

        it 'returns false' do
          expect(task.due_soon?).to be false
        end
      end

      context 'when task is due beyond 3 days' do
        let(:task) { create(:task, due_date: 4.days.from_now, status: :pending) }

        it 'returns false' do
          expect(task.due_soon?).to be false
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'after_create' do
      it 'sends task assigned notification' do
        expect(NotificationService).to receive(:send_task_assigned_notification)
        create(:task, user: user, festival: festival)
      end
    end

    describe 'after_update' do
      context 'when status changes' do
        it 'sends status change notification' do
          task = create(:task, user: user, festival: festival, status: :pending)
          expect(NotificationService).to receive(:send_task_status_changed_notification)
          task.update(status: :completed)
        end
      end

      context 'when status does not change' do
        it 'does not send notification' do
          task = create(:task, user: user, festival: festival, status: :pending)
          expect(NotificationService).not_to receive(:send_task_status_changed_notification)
          task.update(title: 'Updated title')
        end
      end
    end
  end

  describe 'Active Storage attachments' do
    it 'can have many attachments' do
      expect(task).to respond_to(:attachments)
    end

    it 'can have many images' do
      expect(task).to respond_to(:images)
    end
  end
end
