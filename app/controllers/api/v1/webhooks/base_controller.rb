class Api::V1::Webhooks::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  
  before_action :verify_webhook_signature
  before_action :log_webhook_request

  protected

  def verify_webhook_signature
    # This will be implemented per webhook provider
    # Each webhook provider has its own signature verification method
    true
  end

  def log_webhook_request
    Rails.logger.info "Webhook received: #{self.class.name} - #{request.method} #{request.path}"
    Rails.logger.info "Headers: #{request.headers.env.select { |k, v| k.start_with?('HTTP_') }}"
    Rails.logger.info "Body: #{request.body.read}" if request.body.present?
    request.body.rewind if request.body.respond_to?(:rewind)
  end

  def webhook_success(message = 'Webhook processed successfully', data = {})
    render json: {
      status: 'success',
      message: message,
      timestamp: Time.current.iso8601,
      data: data
    }, status: :ok
  end

  def webhook_error(message = 'Webhook processing failed', status = :bad_request, details = {})
    render json: {
      status: 'error',
      message: message,
      timestamp: Time.current.iso8601,
      details: details
    }, status: status
  end

  def webhook_accepted(message = 'Webhook accepted for processing')
    render json: {
      status: 'accepted',
      message: message,
      timestamp: Time.current.iso8601
    }, status: :accepted
  end

  private

  def authenticate_webhook_signature(secret, signature_header, payload)
    return false unless signature_header && secret

    expected_signature = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      secret,
      payload
    )

    signature_header == "sha256=#{expected_signature}"
  end
end