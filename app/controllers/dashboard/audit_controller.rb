require "csv"

module Dashboard
  class AuditController < ApplicationController
    before_action :authenticate_user!

    PER_PAGE = 50

    def index
      @filters = filter_params
      @events  = scoped_events.recent_first

      respond_to do |format|
        format.html do
          @page    = [ params[:page].to_i, 1 ].max
          @total   = @events.count
          @events  = @events.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
          @pages   = (@total.to_f / PER_PAGE).ceil
        end
        format.csv do
          send_data render_csv(@events.limit(10_000)),
                    type: "text/csv",
                    filename: "audit-#{Date.current}.csv"
        end
      end
    end

    def show
      @event = current_account.audit_events.find(params[:id])
    end

    private

    def scoped_events
      events = current_account.audit_events
      events = events.by_actor_type(@filters[:actor_type]) if @filters[:actor_type].present?
      events = events.by_action(@filters[:event_action])   if @filters[:event_action].present?
      events = events.where(target_type: @filters[:target_type]) if @filters[:target_type].present?
      events = events.where(created_at: parse_from(@filters[:from])..) if @filters[:from].present?
      events = events.where(created_at: ..parse_to(@filters[:to]))     if @filters[:to].present?
      events
    end

    def filter_params
      params.permit(:actor_type, :event_action, :target_type, :from, :to).to_h.symbolize_keys
    end

    def parse_from(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_to(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def render_csv(events)
      CSV.generate do |csv|
        csv << %w[created_at actor_type actor_id action target_type target_id reason request_ip user_agent metadata]
        events.find_each do |event|
          csv << [
            event.created_at.iso8601,
            event.actor_type,
            event.actor_id,
            event.action,
            event.target_type,
            event.target_id,
            event.reason,
            event.request_ip,
            event.user_agent,
            event.metadata.to_json
          ]
        end
      end
    end
  end
end
