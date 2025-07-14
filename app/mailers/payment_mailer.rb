class PaymentMailer < ApplicationMailer
  default from: Rails.application.credentials.smtp[:from_email] || "noreply@festival-platform.com"

  def payment_completed(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @receipt_data = payment.receipt_data

    attachments["receipt_#{@payment.id}.pdf"] = generate_receipt_pdf(@payment) if Rails.env.production?

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】お支払い完了のお知らせ"
    )
  end

  def payment_failed(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @error_message = payment.error_message
    @retry_url = new_festival_payment_url(@festival)

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】お支払いエラーのお知らせ"
    )
  end

  def payment_cancelled(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @cancellation_reason = payment.cancellation_reason

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】お支払いキャンセルのお知らせ"
    )
  end

  def payment_refunded(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @refund_amount = payment.amount

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】返金完了のお知らせ"
    )
  end

  def payment_reminder(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @payment_url = festival_payment_url(@festival, @payment)
    @days_overdue = (Date.current - @payment.created_at.to_date).to_i

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】お支払いのリマインダー"
    )
  end

  def payment_receipt(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @receipt_data = payment.receipt_data

    # Generate and attach PDF receipt
    attachments["receipt_#{@payment.id}.pdf"] = generate_receipt_pdf(@payment)

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】お支払い領収書"
    )
  end

  def bank_transfer_instructions(payment)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @instructions = payment.payment_instructions
    @transfer_deadline = 7.days.from_now.strftime("%Y年%m月%d日")

    mail(
      to: @user.email,
      subject: "【#{@festival.name}】銀行振込のご案内"
    )
  end

  def payment_dispute_notification(payment, dispute_reason)
    @payment = payment
    @festival = payment.festival
    @user = payment.user
    @dispute_reason = dispute_reason
    @contact_email = Rails.application.credentials.support_email || "support@festival-platform.com"

    # Send to both user and festival organizers
    recipients = [ @user.email ] + @festival.organizers.pluck(:email)

    mail(
      to: recipients.uniq,
      subject: "【#{@festival.name}】お支払いに関する異議申し立て"
    )
  end

  def daily_payment_summary(date = Date.current)
    @date = date
    @payments = Payment.where(created_at: @date.beginning_of_day..@date.end_of_day)
    @completed_payments = @payments.completed
    @failed_payments = @payments.failed
    @pending_payments = @payments.pending

    @total_revenue = @completed_payments.sum(:amount)
    @total_fees = @completed_payments.sum(:processing_fee)
    @net_revenue = @total_revenue - @total_fees

    @payment_methods_breakdown = @completed_payments.group(:payment_method).sum(:amount)

    # Send to admins
    admin_emails = User.admin.pluck(:email)

    mail(
      to: admin_emails,
      subject: "日次支払いサマリー - #{@date.strftime('%Y年%m月%d日')}"
    )
  end

  def weekly_payment_report(start_date = 1.week.ago.beginning_of_week)
    @start_date = start_date
    @end_date = start_date.end_of_week
    @payments = Payment.where(created_at: @start_date..@end_date)

    @weekly_stats = {
      total_payments: @payments.count,
      completed_payments: @payments.completed.count,
      total_revenue: @payments.completed.sum(:amount),
      average_transaction: @payments.completed.average(:amount)&.round(2) || 0,
      conversion_rate: @payments.count > 0 ? (@payments.completed.count.to_f / @payments.count * 100).round(2) : 0
    }

    @daily_breakdown = @payments.group_by_day(:created_at).count
    @method_breakdown = @payments.completed.group(:payment_method).sum(:amount)
    @festival_breakdown = @payments.completed.joins(:festival).group("festivals.name").sum(:amount)

    # Attach CSV data
    attachments["payment_report_#{@start_date.strftime('%Y%m%d')}_#{@end_date.strftime('%Y%m%d')}.csv"] = generate_csv_report(@payments)

    # Send to admins and finance team
    recipient_emails = User.where(role: [ :admin, :system_admin ]).pluck(:email)

    mail(
      to: recipient_emails,
      subject: "週次支払いレポート - #{@start_date.strftime('%Y年%m月%d日')}〜#{@end_date.strftime('%Y年%m月%d日')}"
    )
  end

  private

  def generate_receipt_pdf(payment)
    # In a real implementation, this would use a PDF generation library like Prawn
    # For now, return a simple text receipt
    receipt_text = <<~RECEIPT
      ==========================================
      【電子領収書】
      ==========================================

      発行日: #{Time.current.strftime('%Y年%m月%d日')}
      領収書番号: #{payment.id}-#{payment.created_at.strftime('%Y%m%d')}

      ------------------------------------------
      お客様情報:
      ------------------------------------------
      お名前: #{payment.customer_name}
      メールアドレス: #{payment.customer_email}

      ------------------------------------------
      お支払い詳細:
      ------------------------------------------
      イベント名: #{payment.festival.name}
      金額: #{payment.formatted_amount}
      決済方法: #{payment.payment_method.humanize}
      取引ID: #{payment.external_transaction_id}
      決済日時: #{payment.confirmed_at&.strftime('%Y年%m月%d日 %H:%M') || '処理中'}

      ------------------------------------------
      内訳:
      ------------------------------------------
      商品・サービス: #{payment.description || 'イベント参加費'}
      小計: ¥#{payment.amount.to_s(:delimited)}
      決済手数料: ¥#{payment.processing_fee.to_s(:delimited)}

      ==========================================

      この領収書は電子的に発行されたものです。

      お問い合わせ:
      #{Rails.application.credentials.support_email || 'support@festival-platform.com'}

      ==========================================
    RECEIPT

    receipt_text
  end

  def generate_csv_report(payments)
    require "csv"

    CSV.generate do |csv|
      csv << [
        "ID", "祭り名", "ユーザー名", "金額", "決済方法", "ステータス",
        "作成日", "処理日", "確認日", "取引ID"
      ]

      payments.includes(:festival, :user).each do |payment|
        csv << [
          payment.id,
          payment.festival.name,
          payment.user.display_name,
          payment.amount,
          payment.payment_method.humanize,
          payment.status.humanize,
          payment.created_at.strftime("%Y-%m-%d %H:%M"),
          payment.processed_at&.strftime("%Y-%m-%d %H:%M"),
          payment.confirmed_at&.strftime("%Y-%m-%d %H:%M"),
          payment.external_transaction_id
        ]
      end
    end
  end

  def new_festival_payment_url(festival)
    Rails.application.routes.url_helpers.new_festival_payment_url(festival, host: default_url_host)
  end

  def festival_payment_url(festival, payment)
    Rails.application.routes.url_helpers.festival_payment_url(festival, payment, host: default_url_host)
  end

  def default_url_host
    Rails.application.credentials.default_host || "localhost:3000"
  end
end
