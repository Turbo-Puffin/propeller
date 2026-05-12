module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_key!
    attr_reader :current_api_key, :current_account
  end

  private

  def authenticate_api_key!
    token = bearer_token
    return render_unauthorized("missing_token", "Missing Authorization header") if token.blank?

    api_key = ApiKey.authenticate(token)
    return render_unauthorized("invalid_token", "Invalid API key") unless api_key

    @current_api_key = api_key
    @current_account = api_key.account
    api_key.touch_last_used!
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")
    header.sub(/\ABearer\s+/, "").strip
  end

  def render_unauthorized(code, message)
    render json: { error: { code: code, message: message } }, status: :unauthorized
  end
end
