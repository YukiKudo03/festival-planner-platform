class VendorApplicationDeadlineJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Starting vendor application deadline check at #{Time.current}"

    begin
      VendorApplicationWorkflowService.process_deadline_checks
      Rails.logger.info "Vendor application deadline check completed successfully"
    rescue => error
      Rails.logger.error "Vendor application deadline check failed: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      raise error
    end
  end
end
