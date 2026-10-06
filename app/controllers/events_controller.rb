class EventsController < ApplicationController
  def index
    @events = Event
      .where("starts_at >= ?", Time.current)
      .order(starts_at: :asc)
  end
end