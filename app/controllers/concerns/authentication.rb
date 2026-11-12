module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def current_user
      Current.session&.user
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= (find_session_by_cookie || find_session_by_header)
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def find_session_by_header
      token = api_token_from_header
      return unless token.present?

      if token.match?(/\A\d+\z/) && (session = Session.find_by(id: token))
        return session
      end

      if (user = User.find_by_token_for(:api_token, token))
        return user.sessions.order(created_at: :desc).first || user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      end

      configured_token = ENV["SONZRA_API_TOKEN"].presence || ENV["API_TOKEN"].presence
      if configured_token.present? && ActiveSupport::SecurityUtils.secure_compare(token, configured_token)
        user = User.first
        return user&.sessions&.order(created_at: :desc)&.first || user&.sessions&.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      end

      nil
    end

    def api_token_from_header
      header_token = if request.headers["Authorization"].to_s.start_with?("Bearer ")
        request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
      else
        request.headers["X-API-Token"].presence || request.headers["X-Session-ID"].presence || request.headers["X-Sonzra-Token"].presence
      end

      header_token.presence || params[:token].presence || params[:api_token].presence
    end

    def request_authentication
      if request.format.json? || request.headers["Accept"]&.include?("application/json") || request.path.start_with?("/api/") || request.path.include?("/artwork/") || request.path.include?("/audio/")
        render json: { error: "Unauthorized" }, status: :unauthorized
      else
        session[:return_to_after_authenticating] = request.url if request.get? || request.head?
        redirect_to new_session_path
      end
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
