class ApiAuthenticationError < StandardError
  attr_reader :error_code, :details

  def initialize(message = "Authentication failed", error_code: "AUTH_FAILED", details: {})
    super(message)
    @error_code = error_code
    @details = details
  end
end
