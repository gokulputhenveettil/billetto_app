class MyVotesController < ApplicationController
  before_action :require_authentication!

  def index
    page = [ params[:page].to_i, 1 ].max
    votes = current_user_votes
      .includes(:event)
      .order(updated_at: :desc, id: :desc)
      .offset((page - 1) * EventsController::EVENTS_PER_PAGE)
      .limit(EventsController::EVENTS_PER_PAGE + 1)
      .to_a

    @has_more_events = votes.length > EventsController::EVENTS_PER_PAGE
    page_votes = votes.first(EventsController::EVENTS_PER_PAGE)
    @events = page_votes.map(&:event)
    @votes_by_event_id = page_votes.index_by(&:event_id).transform_values(&:vote_type)
    @next_page = @has_more_events ? page + 1 : nil

    if request.xhr?
      response.headers["X-Next-Page"] = @next_page ? my_votes_path(page: @next_page) : ""
      render partial: "events/event_cards",
        locals: { events: @events, votes_by_event_id: @votes_by_event_id }
    end
  end

  private

  def current_user_votes
    Vote.where(user_id: current_user.id.to_s)
  end
end
