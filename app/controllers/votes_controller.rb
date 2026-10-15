class VotesController < ApplicationController
  before_action :require_authentication!
  before_action :set_event

  def create
    return redirect_to root_path, alert: "Invalid vote type." unless valid_vote_type?

    begin
      Rails.configuration.command_bus.call(
        Voting::CastVote.new(
          event_id: @event.id,
          user_id: current_user.id,
          vote_type: params[:type].to_s.downcase
        )
      )
    rescue Voting::EventClosed
      return redirect_to root_path, alert: "Voting is closed for past events."
    end

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
end
