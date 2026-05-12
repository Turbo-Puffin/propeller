module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :current_account, :logged_in?
    before_action :set_audit_context
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_account
    current_user&.account
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    unless logged_in?
      redirect_to "/login", alert: "Please log in to continue."
    end
  end

  def set_audit_context
    Current.account    = current_account
    Current.actor      = current_user
    Current.request_ip = request.remote_ip
    Current.user_agent = request.user_agent
  end
end
