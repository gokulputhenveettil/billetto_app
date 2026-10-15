class VotesController < ApplicationController
  before_action :require_authentication!
  before_action :set_event

  def create
    return redirect_to root_path, alert: "Invalid vote type." unless valid_vote_type?

    Rails.configuration.command_bus.call(
      VoteCommand.new(
        event_id: @event.id,
        user_id: current_user.id,
        vote_type: params[:type].to_s.downcase
      )
    )

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
