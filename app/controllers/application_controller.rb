# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Clerk::Authenticatable

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    clerk.user # or clerk.session['sub']
  end

  def user_signed_in?
    clerk.session.present?
  end

  def require_authentication!
    redirect_to root_path, alert: "Please sign in to vote." unless user_signed_in?
  end
end