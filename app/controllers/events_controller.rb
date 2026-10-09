class EventsController < ApplicationController
  before_action :set_event, only: :show

  def index
    @events = upcoming_events
  end

  def show
    @event = set_event
  end

  private

  def upcoming_events
    Event.order(starts_at: :asc)
  end

  def set_event
    @event ||= Event.find(params[:id])
  end
end
