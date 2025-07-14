class ApiAuthorizationError < StandardError
  attr_reader :error_code, :required_scope, :current_scopes

  def initialize(message = "Authorization failed", error_code: "AUTH_INSUFFICIENT", required_scope: nil, current_scopes: [])
    super(message)
    @error_code = error_code
    @required_scope = required_scope
    @current_scopes = current_scopes
  end
end
