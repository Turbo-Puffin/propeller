module Settings
  class SegmentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_segment, only: [ :edit, :update, :destroy ]

    def index
      @segments = current_user.account.segments.order(created_at: :desc)
    end

    def new
      @segment = current_user.account.segments.new(rules: default_rules)
      @contact_lists = current_user.account.contact_lists.order(:name)
    end

    def create
      @segment = current_user.account.segments.new(parsed_attributes)
      if @segment.save
        flash[:notice] = "Segment saved."
        redirect_to settings_segments_path
      else
        @contact_lists = current_user.account.contact_lists.order(:name)
        flash.now[:alert] = @segment.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @contact_lists = current_user.account.contact_lists.order(:name)
    end

    def update
      if @segment.update(parsed_attributes)
        flash[:notice] = "Segment updated."
        redirect_to settings_segments_path
      else
        @contact_lists = current_user.account.contact_lists.order(:name)
        flash.now[:alert] = @segment.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @segment.destroy!
      flash[:notice] = "Segment removed."
      redirect_to settings_segments_path
    end

    private

    def set_segment
      @segment = current_user.account.segments.find(params[:id])
    end

    def parsed_attributes
      {
        name: params[:name].to_s.strip,
        contact_list_id: params[:contact_list_id].presence,
        rules: parse_rules(params[:rules])
      }
    end

    def parse_rules(raw)
      return default_rules if raw.blank?
      JSON.parse(raw)
    rescue JSON::ParserError
      { "match" => "all", "rules" => [], "parse_error" => raw.to_s }
    end

    def default_rules
      { "match" => "all", "rules" => [] }
    end
  end
end
