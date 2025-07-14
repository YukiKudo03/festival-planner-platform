class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!

  def not_found
    render status: :not_found
  end

  def internal_server_error
    render status: :internal_server_error
  end

  def unprocessable_entity
    render status: :unprocessable_entity
  end
end
