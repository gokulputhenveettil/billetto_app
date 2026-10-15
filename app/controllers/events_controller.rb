class EventsController < ApplicationController
  EVENTS_PER_PAGE = 20

  before_action :set_event, only: :show

  def index
    page = [ params[:page].to_i, 1 ].max
    events = upcoming_events.offset((page - 1) * EVENTS_PER_PAGE).limit(EVENTS_PER_PAGE + 1).to_a
    @has_more_events = events.length > EVENTS_PER_PAGE
    @events = events.first(EVENTS_PER_PAGE)
    @next_page = @has_more_events ? page + 1 : nil

    if request.xhr?
      response.headers["X-Next-Page"] = @next_page ? events_path(page: @next_page) : ""
      render partial: "event_cards", locals: { events: @events }
    end
  end

  def show
    @event = set_event
  end

  private

  def upcoming_events
    Event.order(starts_at: :desc, id: :desc)
  end

  def set_event
    @event ||= Event.find(params[:id])
  end
end
