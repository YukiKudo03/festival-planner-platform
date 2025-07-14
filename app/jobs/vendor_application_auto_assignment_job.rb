class VendorApplicationAutoAssignmentJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info "Starting auto-assignment of vendor applications at #{Time.current}"

    begin
      VendorApplicationWorkflowService.auto_assign_reviewers
      Rails.logger.info "Auto-assignment of vendor applications completed successfully"
    rescue => error
      Rails.logger.error "Auto-assignment failed: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      raise error
    end
  end
end
