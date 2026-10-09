# app/helpers/application_helper.rb
module ApplicationHelper
  def clerk_frontend_api
    key = ENV["CLERK_PUBLISHABLE_KEY"].to_s
    # Extract the base64 part after the prefix
    encoded_part = key.sub(/^pk_(test|live)_/, "")
    return "" if encoded_part.blank?

    # Decode and strip the trailing '$'
    Base64.decode64(encoded_part).delete_suffix("$")
  rescue StandardError
    ""
  end
end