# app/controllers/concerns/authenticatable.rb
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_clerk_user
    helper_method :current_user, :user_signed_in?
  end

  private

  def authenticate_clerk_user
    token = request.headers["Authorization"]&.split(" ")&.last || cookies["__session"]
    return if token.blank?

    # Verify session JWT using Clerk's SDK / JWKS endpoint
    claims = Clerk::SDK.new.sessions.verify_token(token)
    
    # Clerk stores user identifier in the "sub" claim
    @current_user = OpenStruct.new(
      id: claims["sub"],
      session_id: claims["sid"],
      claims: claims
    )
  rescue StandardError => e
    Rails.logger.debug { "Clerk verification failed: #{e.message}" }
    @current_user = nil
  end

  def current_user
    @current_user
  end

  def user_signed_in?
    current_user.present?
  end

  def require_authentication!
    return if user_signed_in?

    respond_to do |format|
      format.html do
        redirect_to root_path, alert: "You must be signed in to vote."
      end
      format.json do
        render json: { error: "Authentication required" }, status: :unauthorized
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "flash-messages",
          partial: "shared/flash",
          locals: { alert: "You must be signed in to vote." }
        ), status: :unauthorized
      end
    end
  end
end
