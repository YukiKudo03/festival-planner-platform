class LineTaskParsingJob < ApplicationJob
  queue_as :default

  def perform(line_message)
    Rails.logger.info "Processing LINE message for task parsing: #{line_message.id}"

    return if line_message.processed?

    begin
      result = LineTaskParserService.new(line_message).process_message

      if result[:success]
        line_message.update!(
          is_processed: true,
          intent_type: result[:intent_type],
          confidence_score: result[:confidence_score],
          parsed_content: result[:parsed_content],
          task: result[:task]
        )

        Rails.logger.info "Successfully processed LINE message #{line_message.id}: #{result[:intent_type]}"

        # Send confirmation if task was created
        if result[:task].present?
          send_task_confirmation(line_message, result[:task])
        end

        # Send status response for inquiries
        if result[:intent_type] == "status_inquiry"
          # Status message already sent by LineTaskParserService
          Rails.logger.info "Status inquiry response sent for message #{line_message.id}"
        end

      else
        line_message.add_processing_error(result[:error])
        Rails.logger.warn "Failed to process LINE message #{line_message.id}: #{result[:error]}"
      end

    rescue => e
      error_message = "Processing failed: #{e.message}"
      line_message.add_processing_error(error_message)
      Rails.logger.error "LINE task parsing job failed for message #{line_message.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def send_task_confirmation(line_message, task)
    return unless line_message.line_group.notification_enabled?

    confirmation_text = build_task_confirmation_message(line_message, task)
    line_message.line_group.send_message(confirmation_text)

    Rails.logger.info "Sent task confirmation for task #{task.id} to group #{line_message.line_group.name}"
  rescue => e
    Rails.logger.error "Failed to send task confirmation: #{e.message}"
  end

  def build_task_confirmation_message(line_message, task)
    case line_message.intent_type
    when "task_creation"
      "✅ タスクを作成しました\n\n" \
      "📋 タイトル：#{task.title}\n" \
      "📅 期限：#{task.due_date&.strftime('%Y年%m月%d日') || '未設定'}\n" \
      "👤 担当者：#{task.user&.display_name || '未設定'}\n" \
      "⚠️ 優先度：#{task.priority_label}\n" \
      "📊 ステータス：#{task.status_label}"

    when "task_completion"
      "🎉 タスクが完了しました\n\n" \
      "📋 タスク：#{task.title}\n" \
      "👤 完了者：#{task.user&.display_name}\n" \
      "🕐 完了時刻：#{Time.current.strftime('%Y年%m月%d日 %H:%M')}"

    when "task_assignment"
      "📝 タスクが再割り当てされました\n\n" \
      "📋 タスク：#{task.title}\n" \
      "👤 新担当者：#{task.user&.display_name}\n" \
      "📅 期限：#{task.due_date&.strftime('%Y年%m月%d日') || '未設定'}"

    else
      "📋 メッセージを処理しました\n" \
      "処理内容：#{line_message.intent_type.humanize}"
    end
  end
end
