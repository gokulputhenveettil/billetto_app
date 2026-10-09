class VotesController < ApplicationController
  before_action :require_authentication!
  before_action :set_event

  def create
    return redirect_to root_path, alert: "Invalid vote type." unless valid_vote_type?

    publish_vote

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to root_path, notice: "Vote recorded successfully." }
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def valid_vote_type?
    %w[upvote downvote].include?(params[:type].to_s.downcase)
  end

  def publish_vote
    event_store = Rails.configuration.event_store
    domain_event = vote_event_class.new(
      data: {
        event_id: @event.id,
        user_id: current_user.id,
        voted_at: Time.current.iso8601
      }
    )

    event_store.publish(domain_event, stream_name: "Event$#{@event.id}")
    event_store.link(domain_event.event_id, stream_name: "User$#{current_user.id}")
  end

  def vote_event_class
    case params[:type].to_s.downcase
    when "upvote" then EventUpvoted
    when "downvote" then EventDownvoted
    end
  end
end
