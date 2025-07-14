class PaymentNotificationService
  def self.payment_completed(payment)
    # Create notification for user
    payment.user.notifications.create!(
      notification_type: "payment_completed",
      title: "支払いが完了しました",
      message: "#{payment.festival.name}の支払い（#{payment.formatted_amount}）が正常に処理されました。",
      notifiable: payment,
      sender: nil
    )

    # Create notification for festival organizers
    payment.festival.organizers.each do |organizer|
      organizer.notifications.create!(
        notification_type: "payment_received",
        title: "新しい支払いを受領しました",
        message: "#{payment.user.display_name}さんから#{payment.formatted_amount}の支払いを受領しました。（#{payment.festival.name}）",
        notifiable: payment,
        sender: payment.user
      )
    end

    # Send email notifications if enabled
    if payment.user.notification_setting_for("payment_completed").email_enabled?
      PaymentMailer.payment_completed(payment).deliver_later
    end

    # Log the completion
    Rails.logger.info "Payment completed: #{payment.id} - #{payment.formatted_amount} for festival #{payment.festival.id}"
  end

  def self.payment_failed(payment)
    # Create notification for user
    payment.user.notifications.create!(
      notification_type: "payment_failed",
      title: "支払いに失敗しました",
      message: "#{payment.festival.name}の支払い（#{payment.formatted_amount}）の処理に失敗しました。再度お試しください。",
      notifiable: payment,
      sender: nil
    )

    # Send email notification
    if payment.user.notification_setting_for("payment_failed").email_enabled?
      PaymentMailer.payment_failed(payment).deliver_later
    end

    # Log the failure
    Rails.logger.warn "Payment failed: #{payment.id} - #{payment.error_message}"
  end

  def self.payment_cancelled(payment)
    # Create notification for user
    payment.user.notifications.create!(
      notification_type: "payment_cancelled",
      title: "支払いがキャンセルされました",
      message: "#{payment.festival.name}の支払い（#{payment.formatted_amount}）がキャンセルされました。",
      notifiable: payment,
      sender: nil
    )

    # Create notification for festival organizers if payment was being processed
    if payment.processing? || payment.external_transaction_id.present?
      payment.festival.organizers.each do |organizer|
        organizer.notifications.create!(
          notification_type: "payment_cancelled",
          title: "支払いがキャンセルされました",
          message: "#{payment.user.display_name}さんの支払い（#{payment.formatted_amount}）がキャンセルされました。（#{payment.festival.name}）",
          notifiable: payment,
          sender: payment.user
        )
      end
    end

    # Send email notification
    if payment.user.notification_setting_for("payment_cancelled").email_enabled?
      PaymentMailer.payment_cancelled(payment).deliver_later
    end

    # Log the cancellation
    Rails.logger.info "Payment cancelled: #{payment.id} - Reason: #{payment.cancellation_reason}"
  end

  def self.payment_refunded(payment)
    # Create notification for user
    payment.user.notifications.create!(
      notification_type: "payment_refunded",
      title: "返金が完了しました",
      message: "#{payment.festival.name}の支払い（#{payment.formatted_amount}）の返金処理が完了しました。",
      notifiable: payment,
      sender: nil
    )

    # Create notification for festival organizers
    payment.festival.organizers.each do |organizer|
      organizer.notifications.create!(
        notification_type: "payment_refunded",
        title: "返金処理を実行しました",
        message: "#{payment.user.display_name}さんに#{payment.formatted_amount}の返金を実行しました。（#{payment.festival.name}）",
        notifiable: payment,
        sender: nil
      )
    end

    # Send email notifications
    if payment.user.notification_setting_for("payment_refunded").email_enabled?
      PaymentMailer.payment_refunded(payment).deliver_later
    end

    # Log the refund
    Rails.logger.info "Payment refunded: #{payment.id} - #{payment.formatted_amount}"
  end

  def self.payment_reminder(payment)
    return unless payment.pending?

    # Create reminder notification
    payment.user.notifications.create!(
      notification_type: "payment_reminder",
      title: "支払いが未完了です",
      message: "#{payment.festival.name}の支払い（#{payment.formatted_amount}）が未完了です。お早めにお支払いください。",
      notifiable: payment,
      sender: nil
    )

    # Send email reminder
    if payment.user.notification_setting_for("payment_reminder").email_enabled?
      PaymentMailer.payment_reminder(payment).deliver_later
    end

    Rails.logger.info "Payment reminder sent: #{payment.id}"
  end

  def self.bulk_payment_reminder
    # Find pending payments older than 24 hours
    pending_payments = Payment.pending
                              .where("created_at < ?", 24.hours.ago)
                              .where("created_at > ?", 7.days.ago)
                              .includes(:user, :festival)

    pending_payments.find_each do |payment|
      # Check if reminder was already sent recently
      last_reminder = payment.user.notifications
                             .where(notification_type: "payment_reminder")
                             .where(notifiable: payment)
                             .order(created_at: :desc)
                             .first

      # Don't send reminder if one was sent in the last 48 hours
      next if last_reminder && last_reminder.created_at > 48.hours.ago

      payment_reminder(payment)
    end
  end

  def self.payment_status_update(payment, old_status, new_status)
    # Generic status update notification for internal tracking
    Rails.logger.info "Payment status changed: #{payment.id} from #{old_status} to #{new_status}"

    # Create internal notification for admins
    User.admin.find_each do |admin|
      admin.notifications.create!(
        notification_type: "admin_payment_status_change",
        title: "支払いステータスが変更されました",
        message: "支払いID #{payment.id} のステータスが #{old_status} から #{new_status} に変更されました。",
        notifiable: payment,
        sender: nil
      )
    end
  end

  def self.payment_dispute_opened(payment, dispute_reason)
    # Create notification for festival organizers
    payment.festival.organizers.each do |organizer|
      organizer.notifications.create!(
        notification_type: "payment_dispute",
        title: "支払いに関する異議申し立てがありました",
        message: "支払いID #{payment.id}（#{payment.formatted_amount}）に対して異議申し立てがありました。理由: #{dispute_reason}",
        notifiable: payment,
        sender: payment.user
      )
    end

    # Create notification for user
    payment.user.notifications.create!(
      notification_type: "payment_dispute_acknowledged",
      title: "異議申し立てを受け付けました",
      message: "#{payment.festival.name}の支払いに対する異議申し立てを受け付けました。詳細は後日ご連絡いたします。",
      notifiable: payment,
      sender: nil
    )

    Rails.logger.warn "Payment dispute opened: #{payment.id} - Reason: #{dispute_reason}"
  end
end
