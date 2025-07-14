require 'rails_helper'

RSpec.describe LineTaskParserService do
  let(:user) { create(:user) }
  let(:festival) { create(:festival, user: user) }
  let(:line_integration) { create(:line_integration, festival: festival, user: user) }
  let(:line_group) { create(:line_group, line_integration: line_integration) }
  let(:line_message) { create(:line_message, line_group: line_group, user: user) }
  let(:service) { described_class.new(line_message) }

  before do
    allow(NotificationService).to receive(:send_task_assigned_notification)
    allow(NotificationService).to receive(:send_task_status_changed_notification)
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      service = described_class.new(line_message)
      expect(service.instance_variable_get(:@message)).to eq(line_message)
      expect(service.instance_variable_get(:@text)).to eq(line_message.message_text)
      expect(service.instance_variable_get(:@line_group)).to eq(line_group)
      expect(service.instance_variable_get(:@festival)).to eq(festival)
    end
  end

  describe '#process_message' do
    context 'when message is already processed' do
      before do
        line_message.update!(is_processed: true)
      end

      it 'returns error for already processed message' do
        result = service.process_message
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Message already processed')
      end
    end

    context 'with task creation message' do
      let(:line_message) { create(:line_message, line_group: line_group, user: user, message_text: 'タスク: 会場設営をする') }

      it 'creates task successfully' do
        expect {
          result = service.process_message
          expect(result[:success]).to be true
          expect(result[:intent_type]).to eq('task_creation')
          expect(result[:task]).to be_a(Task)
          expect(result[:task].title).to include('会場設営')
        }.to change(Task, :count).by(1)
      end
    end

    context 'with task completion message' do
      let!(:task) { create(:task, festival: festival, user: user, title: '音響チェック', status: 'in_progress') }
      let(:line_message) { create(:line_message, line_group: line_group, user: user, message_text: '音響チェック完了') }

      it 'completes task successfully' do
        result = service.process_message
        expect(result[:success]).to be true
        expect(result[:intent_type]).to eq('task_completion')
        expect(result[:task]).to eq(task)
        task.reload
        expect(task.status).to eq('completed')
      end
    end

    context 'with assignment message' do
      let(:assignee) { create(:user, first_name: '田中') }
      let(:line_message) { create(:line_message, line_group: line_group, user: user, message_text: 'タスク: 受付準備 @田中') }

      it 'creates task with assignment' do
        expect {
          result = service.process_message
          expect(result[:success]).to be true
          expect(result[:intent_type]).to eq('task_creation')
          expect(result[:task].user).to eq(assignee)
        }.to change(Task, :count).by(1)
      end
    end

    context 'with status inquiry message' do
      let!(:pending_task) { create(:task, festival: festival, user: user, status: 'pending') }
      let!(:completed_task) { create(:task, festival: festival, user: user, status: 'completed') }
      let(:line_message) { create(:line_message, line_group: line_group, user: user, message_text: '進捗確認') }

      before do
        allow(line_group).to receive(:send_message)
      end

      it 'handles status inquiry' do
        expect(line_group).to receive(:send_message).with(/タスク状況/)
        result = service.process_message
        expect(result[:success]).to be true
        expect(result[:intent_type]).to eq('status_inquiry')
        expect(result[:parsed_content][:status_summary]).to include(:pending, :completed)
      end
    end

    context 'with general message' do
      let(:line_message) { create(:line_message, line_group: line_group, user: user, message_text: 'こんにちは') }

      it 'classifies as general message' do
        result = service.process_message
        expect(result[:success]).to be true
        expect(result[:intent_type]).to eq('general_message')
        expect(result[:task]).to be_nil
      end
    end

    context 'when exception occurs' do
      before do
        allow(service).to receive(:analyze_intent).and_raise(StandardError, 'Processing error')
        allow(Rails.logger).to receive(:error)
      end

      it 'handles exception and returns error' do
        expect(Rails.logger).to receive(:error).with(/LineTaskParserService error/)
        result = service.process_message
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Processing error')
      end
    end
  end

  describe 'private methods' do
    describe '#analyze_intent' do
      context 'with task creation keywords' do
        it 'detects task creation intent' do
          result = service.send(:analyze_intent, 'タスク: 準備作業をする')
          expect(result[:intent]).to eq('task_creation')
          expect(result[:confidence]).to be > 0.4
        end

        it 'increases confidence with title' do
          result = service.send(:analyze_intent, 'タスク: 明確なタイトル')
          expect(result[:confidence]).to be > 0.7
        end

        it 'increases confidence with deadline' do
          result = service.send(:analyze_intent, 'タスク: 作業 明日まで')
          expect(result[:parsed_data][:has_deadline]).to be true
        end
      end

      context 'with completion keywords' do
        it 'detects task completion intent' do
          result = service.send(:analyze_intent, '作業完了しました')
          expect(result[:intent]).to eq('task_completion')
          expect(result[:confidence]).to eq(0.7)
        end
      end

      context 'with assignment keywords' do
        it 'detects task assignment intent' do
          result = service.send(:analyze_intent, '@田中さん お願いします')
          expect(result[:intent]).to eq('task_assignment')
          expect(result[:confidence]).to be >= 0.3
        end
      end

      context 'with status keywords' do
        it 'detects status inquiry intent' do
          result = service.send(:analyze_intent, '進捗はどうですか？')
          expect(result[:intent]).to eq('status_inquiry')
          expect(result[:confidence]).to eq(0.6)
        end
      end
    end

    describe '#create_task_from_message' do
      let(:intent_result) do
        {
          intent: 'task_creation',
          confidence: 0.8,
          parsed_data: {
            title: '会場設営',
            description: '会場の設営作業',
            priority: 'high',
            deadline: Date.tomorrow
          }
        }
      end

      it 'creates task with parsed details' do
        expect {
          result = service.send(:create_task_from_message, intent_result)
          expect(result[:success]).to be true

          task = result[:task]
          expect(task.title).to eq('会場設営')
          expect(task.description).to eq('会場の設営作業')
          expect(task.priority).to eq('high')
          expect(task.due_date).to eq(Date.tomorrow)
          expect(task.created_via_line).to be true
        }.to change(Task, :count).by(1)
      end

      context 'when title extraction fails' do
        let(:intent_result) do
          {
            parsed_data: { title: nil }
          }
        end

        before do
          allow(service).to receive(:extract_title_from_text).and_return(nil)
        end

        it 'returns error for missing title' do
          result = service.send(:create_task_from_message, intent_result)
          expect(result[:success]).to be false
          expect(result[:error]).to eq('Could not extract task title')
        end
      end

      context 'when task save fails' do
        before do
          allow_any_instance_of(Task).to receive(:save).and_return(false)
          allow_any_instance_of(Task).to receive(:errors).and_return(
            double('errors', full_messages: [ 'Title cannot be blank' ])
          )
        end

        it 'returns error with validation messages' do
          result = service.send(:create_task_from_message, intent_result)
          expect(result[:success]).to be false
          expect(result[:error]).to include('Task creation failed')
        end
      end
    end

    describe '#complete_task_from_message' do
      let!(:task) { create(:task, festival: festival, user: user, title: 'テスト作業', status: 'in_progress') }
      let(:intent_result) do
        {
          confidence: 0.7,
          parsed_data: { task_title: 'テスト作業' }
        }
      end

      before do
        allow(service).to receive(:find_task_by_title).with('テスト作業').and_return(task)
      end

      it 'completes specified task' do
        result = service.send(:complete_task_from_message, intent_result)
        expect(result[:success]).to be true
        expect(result[:task]).to eq(task)

        task.reload
        expect(task.status).to eq('completed')
        expect(task.completed_at).to be_present
      end

      it 'sends status change notification' do
        expect(NotificationService).to receive(:send_task_status_changed_notification).with(task, 'in_progress')
        service.send(:complete_task_from_message, intent_result)
      end

      context 'when task not found' do
        before do
          allow(service).to receive(:find_task_by_title).and_return(nil)
          allow(service).to receive(:find_recent_user_task).and_return(nil)
        end

        it 'returns error for missing task' do
          result = service.send(:complete_task_from_message, intent_result)
          expect(result[:success]).to be false
          expect(result[:error]).to eq('Could not find task to complete')
        end
      end
    end

    describe '#handle_status_inquiry' do
      let!(:pending_task) { create(:task, festival: festival, user: user, status: 'pending') }
      let!(:completed_task) { create(:task, festival: festival, user: user, status: 'completed') }
      let!(:overdue_task) { create(:task, festival: festival, user: user, status: 'pending', due_date: 1.day.ago) }
      let(:intent_result) { { confidence: 0.6, parsed_data: {} } }

      before do
        allow(line_group).to receive(:send_message)
      end

      it 'calculates status summary correctly' do
        result = service.send(:handle_status_inquiry, intent_result)
        expect(result[:success]).to be true

        summary = result[:parsed_content][:status_summary]
        expect(summary[:pending]).to eq(2) # pending + overdue
        expect(summary[:completed]).to eq(1)
        expect(summary[:overdue]).to eq(1)
      end

      it 'sends status message to group' do
        expect(line_group).to receive(:send_message).with(/📊 タスク状況/)
        service.send(:handle_status_inquiry, intent_result)
      end
    end

    describe 'text processing helpers' do
      describe '#normalize_text' do
        it 'normalizes text correctly' do
          result = service.send(:normalize_text, 'タスク：会場設営！！！')
          expect(result).to eq('タスク 会場設営')
        end
      end

      describe '#contains_task_keywords?' do
        it 'detects task keywords' do
          expect(service.send(:contains_task_keywords?, 'タスク作成')).to be true
          expect(service.send(:contains_task_keywords?, 'やること追加')).to be true
          expect(service.send(:contains_task_keywords?, '普通のメッセージ')).to be false
        end
      end

      describe '#contains_completion_keywords?' do
        it 'detects completion keywords' do
          expect(service.send(:contains_completion_keywords?, '作業完了')).to be true
          expect(service.send(:contains_completion_keywords?, 'done')).to be true
          expect(service.send(:contains_completion_keywords?, '未完了')).to be false
        end
      end

      describe '#contains_mentions?' do
        it 'detects mentions' do
          expect(service.send(:contains_mentions?, '@田中さん')).to be true
          expect(service.send(:contains_mentions?, '田中さん')).to be false
        end
      end
    end

    describe 'parsing helpers' do
      describe '#parse_task_details' do
        it 'parses task details correctly' do
          result = service.send(:parse_task_details, 'タスク 会場設営 明日まで 緊急')
          expect(result[:title]).to eq('会場設営 明日まで 緊急')
          expect(result[:has_title]).to be true
          expect(result[:has_deadline]).to be true
          expect(result[:priority]).to eq('high')
        end
      end

      describe '#extract_deadline' do
        it 'extracts relative dates' do
          expect(service.send(:extract_deadline, '明日まで')).to eq(Date.current + 1.day)
          expect(service.send(:extract_deadline, '今日中に')).to eq(Date.current)
          expect(service.send(:extract_deadline, '明後日')).to eq(Date.current + 2.days)
        end

        it 'extracts numeric dates' do
          expect(service.send(:extract_deadline, '15日まで')).to eq(Date.new(Date.current.year, Date.current.month, 15))
        end

        it 'returns nil for no date' do
          expect(service.send(:extract_deadline, '期限なし')).to be_nil
        end
      end

      describe '#extract_priority' do
        it 'extracts priority keywords' do
          expect(service.send(:extract_priority, '緊急作業')).to eq('high')
          expect(service.send(:extract_priority, '普通の作業')).to eq('medium')
          expect(service.send(:extract_priority, '後でやる')).to eq('low')
          expect(service.send(:extract_priority, '作業')).to eq('medium')
        end
      end

      describe '#extract_mentions' do
        it 'extracts user mentions' do
          mentions = service.send(:extract_mentions, '@田中 @佐藤さん お疲れ様')
          expect(mentions).to match_array([ '田中', '佐藤さん' ])
        end
      end
    end

    describe 'user and task finding helpers' do
      describe '#find_mentioned_user' do
        let!(:user1) { create(:user, first_name: '田中', last_name: '太郎') }
        let!(:user2) { create(:user, email: 'sato@example.com') }

        it 'finds user by name mention' do
          result = service.send(:find_mentioned_user, [ '田中' ])
          expect(result).to eq(user1)
        end

        it 'finds user by email mention' do
          result = service.send(:find_mentioned_user, [ 'sato' ])
          expect(result).to eq(user2)
        end

        it 'returns nil for non-existent user' do
          result = service.send(:find_mentioned_user, [ '存在しない' ])
          expect(result).to be_nil
        end
      end

      describe '#find_task_by_title' do
        let!(:task1) { create(:task, festival: festival, title: '会場設営作業') }
        let!(:task2) { create(:task, festival: festival, title: '音響チェック') }

        it 'finds task by partial title match' do
          result = service.send(:find_task_by_title, '会場設営')
          expect(result).to eq(task1)
        end

        it 'returns most recent matching task' do
          newer_task = create(:task, festival: festival, title: '会場設営準備')
          result = service.send(:find_task_by_title, '会場設営')
          expect(result).to eq(newer_task)
        end

        it 'returns nil for no match' do
          result = service.send(:find_task_by_title, '存在しない作業')
          expect(result).to be_nil
        end
      end

      describe '#find_recent_user_task' do
        let!(:completed_task) { create(:task, festival: festival, user: user, status: 'completed') }
        let!(:pending_task) { create(:task, festival: festival, user: user, status: 'pending') }

        it 'finds most recent incomplete task' do
          result = service.send(:find_recent_user_task)
          expect(result).to eq(pending_task)
        end

        it 'excludes completed tasks' do
          pending_task.destroy
          result = service.send(:find_recent_user_task)
          expect(result).to be_nil
        end
      end
    end

    describe '#build_status_message' do
      let(:status_summary) do
        {
          pending: 3,
          in_progress: 2,
          completed: 5,
          overdue: 1
        }
      end

      it 'builds formatted status message' do
        message = service.send(:build_status_message, status_summary)
        expect(message).to include('📊 タスク状況')
        expect(message).to include('⏳ 待機中: 3件')
        expect(message).to include('🔄 進行中: 2件')
        expect(message).to include('✅ 完了: 5件')
        expect(message).to include('⚠️ 期限切れ: 1件')
      end
    end

    describe '#extract_title_from_text' do
      it 'extracts title after task keywords' do
        result = service.send(:extract_title_from_text, 'タスク：会場設営をする。詳細説明。')
        expect(result).to eq('会場設営をする')
      end

      it 'handles different task keyword formats' do
        result = service.send(:extract_title_from_text, 'やること: 準備作業')
        expect(result).to eq('準備作業')
      end

      it 'returns nil for empty title' do
        result = service.send(:extract_title_from_text, 'タスク：')
        expect(result).to be_nil
      end
    end

    describe '#clean_title' do
      it 'removes common Japanese particles and endings' do
        expect(service.send(:clean_title, 'を準備する')).to eq('準備する')
        expect(service.send(:clean_title, '設営作業です')).to eq('設営作業')
        expect(service.send(:clean_title, 'が必要だ')).to eq('必要だ')
      end
    end
  end

  describe 'constants' do
    it 'defines expected constants' do
      expect(described_class::TASK_KEYWORDS).to include('タスク', 'やること', 'TODO')
      expect(described_class::PRIORITY_KEYWORDS).to have_key('high')
      expect(described_class::COMPLETION_KEYWORDS).to include('完了', '終了', 'done')
      expect(described_class::ASSIGNMENT_KEYWORDS).to include('お願い', '担当', '@')
    end
  end
end
