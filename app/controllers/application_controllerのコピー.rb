class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :render_404
  rescue_from CanCan::AccessDenied, with: :render_403
  rescue_from ActionController::RoutingError, with: :render_404
  
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone, :bio, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :phone, :bio, :role])
  end

  private

  def render_404
    render 'errors/not_found', status: :not_found
  end

  def render_403
    flash[:alert] = 'この操作を実行する権限がありません。'
    redirect_to root_path
  end

  def render_500
    render 'errors/internal_server_error', status: :internal_server_error
  end
end
