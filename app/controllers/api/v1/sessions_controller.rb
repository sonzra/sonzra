module Api
  module V1
    class SessionsController < BaseController
      allow_unauthenticated_access only: :create

      def create
        if (user = User.authenticate_by(params.permit(:email_address, :password)))
          session = user.sessions.create!(
            user_agent: request.user_agent,
            ip_address: request.remote_ip
          )
          Current.session = session
          token = user.generate_token_for(:api_token)
          render json: {
            token: token,
            session_id: session.id,
            user: {
              id: user.id,
              email_address: user.email_address
            }
          }, status: :created
        else
          render json: { error: "Invalid email address or password" }, status: :unauthorized
        end
      end

      def show
        render json: {
          user: {
            id: current_user.id,
            email_address: current_user.email_address
          },
          session_id: Current.session&.id
        }
      end

      def destroy
        terminate_session
        render json: { status: "logged_out" }, status: :ok
      end
    end
  end
end
