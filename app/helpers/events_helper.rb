require "uri"

module EventsHelper
  def safe_billetto_event_url(value)
    return if value.blank?

    uri = URI.parse(value)
    host = uri.host&.downcase

    return unless uri.is_a?(URI::HTTPS)
    return unless host&.match?(/\A(?:[a-z0-9-]+\.)*billetto\.dk\z/)
    return if uri.userinfo.present?

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
