class VirusScanJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 2

  def perform(attachment_ids, user_id)
    user = User.find(user_id)
    attachments = ActiveStorage::Attachment.where(id: attachment_ids)

    scan_results = {
      total_scanned: 0,
      clean_files: 0,
      infected_files: 0,
      scan_errors: 0,
      infected_file_details: [],
      error_details: []
    }

    attachments.each do |attachment|
      begin
        result = scan_single_file(attachment)
        scan_results[:total_scanned] += 1

        case result[:status]
        when "clean"
          scan_results[:clean_files] += 1
        when "infected"
          scan_results[:infected_files] += 1
          scan_results[:infected_file_details] << {
            filename: attachment.blob.filename.to_s,
            virus_name: result[:virus_name],
            action_taken: result[:action_taken]
          }
        when "error"
          scan_results[:scan_errors] += 1
          scan_results[:error_details] << {
            filename: attachment.blob.filename.to_s,
            error: result[:error_message]
          }
        end

      rescue => error
        Rails.logger.error "Virus scan failed for attachment #{attachment.id}: #{error.message}"
        scan_results[:scan_errors] += 1
        scan_results[:error_details] << {
          filename: attachment.blob.filename.to_s,
          error: error.message
        }
      end
    end

    # スキャン結果をユーザーに通知
    send_scan_notification(user, scan_results)

    # 管理者にサマリーを送信（感染ファイルが見つかった場合）
    if scan_results[:infected_files] > 0
      send_admin_notification(scan_results)
    end

    # スキャン履歴を記録
    record_scan_history(user, scan_results)
  end

  private

  def scan_single_file(attachment)
    scanner = VirusScannerService.new

    begin
      attachment.blob.open do |file|
        scan_result = scanner.scan_file(file.path)

        # FileMetadataにスキャン結果を記録
        metadata = FileMetadata.find_by(attachment: attachment)
        if metadata
          if scan_result[:infected]
            metadata.update_virus_scan_result("infected", {
              virus_name: scan_result[:virus_name],
              scanner_version: scan_result[:scanner_version],
              definitions_date: scan_result[:definitions_date]
            })
          else
            metadata.update_virus_scan_result("clean", {
              scanner_version: scan_result[:scanner_version],
              definitions_date: scan_result[:definitions_date]
            })
          end
        end

        if scan_result[:infected]
          action_taken = handle_infected_file(attachment, scan_result)
          {
            status: "infected",
            virus_name: scan_result[:virus_name],
            action_taken: action_taken
          }
        else
          { status: "clean" }
        end
      end
    rescue => error
      Rails.logger.error "Virus scan error for #{attachment.blob.filename}: #{error.message}"

      # エラーをメタデータに記録
      metadata = FileMetadata.find_by(attachment: attachment)
      metadata&.update_virus_scan_result("error", { error_message: error.message })

      {
        status: "error",
        error_message: error.message
      }
    end
  end

  def handle_infected_file(attachment, scan_result)
    filename = attachment.blob.filename.to_s
    virus_name = scan_result[:virus_name]

    Rails.logger.error "VIRUS DETECTED: #{virus_name} in file #{filename}"

    begin
      # ファイルを即座に隔離（削除）
      attachment.purge

      # セキュリティログに記録
      SecurityLog.create!(
        event_type: "virus_detected",
        user: attachment.record.respond_to?(:user) ? attachment.record.user : nil,
        details: {
          filename: filename,
          virus_name: virus_name,
          file_size: attachment.blob.byte_size,
          content_type: attachment.blob.content_type,
          record_type: attachment.record_type,
          record_id: attachment.record_id,
          scanner_version: scan_result[:scanner_version]
        },
        severity: "critical"
      )

      "ファイルを削除しました"
    rescue => error
      Rails.logger.error "Failed to purge infected file: #{error.message}"
      "隔離に失敗しました"
    end
  end

  def send_scan_notification(user, results)
    # ユーザーへの通知
    notification_data = {
      type: "virus_scan_completed",
      title: "ウイルススキャン完了",
      message: generate_user_notification_message(results),
      data: results
    }

    Notification.create!(
      user: user,
      title: notification_data[:title],
      message: notification_data[:message],
      data: notification_data[:data],
      notification_type: "security"
    )

    # メール通知（感染ファイルが見つかった場合）
    if results[:infected_files] > 0
      UserNotificationMailer.virus_scan_completed(user, results).deliver_now
    end
  end

  def send_admin_notification(results)
    # システム管理者への緊急通知
    admin_users = User.where(role: [ :admin, :system_admin ])

    admin_users.each do |admin|
      AdminNotificationMailer.virus_detection_alert(admin, results).deliver_now
    end

    # Slackやその他の監視システムへの通知
    send_security_alert(results) if Rails.env.production?
  end

  def send_security_alert(results)
    # 外部監視システムへのアラート送信
    begin
      alert_data = {
        alert_type: "virus_detection",
        severity: "critical",
        infected_files_count: results[:infected_files],
        details: results[:infected_file_details],
        timestamp: Time.current.iso8601
      }

      # Slack通知
      if ENV["SLACK_SECURITY_WEBHOOK_URL"].present?
        SlackNotificationService.new.send_security_alert(alert_data)
      end

      # 外部SIEM/監視システムへの送信
      if ENV["SECURITY_MONITORING_ENDPOINT"].present?
        SecurityMonitoringService.new.send_alert(alert_data)
      end

    rescue => error
      Rails.logger.error "Failed to send security alert: #{error.message}"
    end
  end

  def record_scan_history(user, results)
    # スキャン履歴をデータベースに記録
    VirusScanHistory.create!(
      user: user,
      scanned_files_count: results[:total_scanned],
      clean_files_count: results[:clean_files],
      infected_files_count: results[:infected_files],
      error_files_count: results[:scan_errors],
      scan_duration: Time.current - @job_started_at,
      scanner_version: VirusScannerService.new.version,
      details: results
    )
  rescue => error
    Rails.logger.warn "Failed to record scan history: #{error.message}"
  end

  def generate_user_notification_message(results)
    total = results[:total_scanned]
    clean = results[:clean_files]
    infected = results[:infected_files]
    errors = results[:scan_errors]

    message_parts = []
    message_parts << "#{total}ファイルをスキャンしました。"

    if infected > 0
      message_parts << "⚠️ #{infected}ファイルでウイルスが検出され、削除されました。"
    elsif clean == total
      message_parts << "✅ すべてのファイルがクリーンです。"
    else
      message_parts << "#{clean}ファイルがクリーンです。"
    end

    if errors > 0
      message_parts << "#{errors}ファイルでスキャンエラーが発生しました。"
    end

    message_parts.join(" ")
  end
end
