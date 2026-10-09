module Billetto
  class DeleteOldEventsJob
    include Sidekiq::Job

    RETENTION_WINDOW = 30.days

    def perform
      deleted_count = Event.where("starts_at < ?", RETENTION_WINDOW.ago).delete_all
      Rails.logger.info("Deleted #{deleted_count} stale Billetto events.")
      deleted_count
    end
  end
end
