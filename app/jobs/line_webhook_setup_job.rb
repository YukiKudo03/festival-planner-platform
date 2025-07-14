class LineWebhookSetupJob < ApplicationJob
  queue_as :default

  def perform(line_integration)
    Rails.logger.info "Setting up webhook for LINE integration: #{line_integration.id}"

    begin
      service = LineIntegrationService.new(line_integration)
      webhook_url = generate_webhook_url

      result = service.register_webhook(webhook_url)

      if result[:success]
        line_integration.update!(
          webhook_url: webhook_url,
          status: :active,
          is_active: true
        )

        Rails.logger.info "Successfully set up webhook for integration #{line_integration.id}"
      else
        line_integration.update!(status: :error)
        Rails.logger.error "Failed to set up webhook for integration #{line_integration.id}: #{result[:error]}"
      end

    rescue => e
      line_integration.update!(status: :error)
      Rails.logger.error "Webhook setup job failed for integration #{line_integration.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end

  private

  def generate_webhook_url
    Rails.application.routes.url_helpers.callback_line_integrations_url(
      host: Rails.application.config.action_mailer.default_url_options[:host],
      protocol: Rails.env.production? ? "https" : "http"
    )
  end
end
