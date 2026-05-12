module Api
  module V1
    class CampaignsController < BaseController
      before_action :set_campaign, only: [ :show, :schedule, :cancel ]

      def index
        scope = current_account.campaigns.order(created_at: :desc)
        render json: {
          data: paginate(scope).map { |c| CampaignSerializer.serialize(c) },
          meta: meta_for(scope)
        }
      end

      def show
        render json: { data: CampaignSerializer.serialize(@campaign) }
      end

      def create
        campaign = current_account.campaigns.new(campaign_params)
        if campaign.save
          render json: { data: CampaignSerializer.serialize(campaign) }, status: :created
        else
          render_validation_errors(campaign)
        end
      end

      def schedule
        return render_already_finalized if @campaign.sent? || @campaign.sending?

        scheduled_at = parse_scheduled_at
        return render_error(code: "validation_failed", message: "scheduled_at must be a valid ISO8601 timestamp", status: :unprocessable_entity, fields: { scheduled_at: [ "invalid" ] }) if params[:scheduled_at].present? && scheduled_at.nil?

        @campaign.scheduled_at = scheduled_at || Time.current
        @campaign.status = :scheduled
        if @campaign.save
          render json: { data: CampaignSerializer.serialize(@campaign) }
        else
          render_validation_errors(@campaign)
        end
      end

      def cancel
        return render_error(code: "invalid_state", message: "Campaign cannot be cancelled in its current state", status: :unprocessable_entity) unless @campaign.scheduled? || @campaign.paused?

        @campaign.update!(status: :draft, scheduled_at: nil)
        render json: { data: CampaignSerializer.serialize(@campaign) }
      end

      private

      def set_campaign
        @campaign = current_account.campaigns.find(params[:id])
      end

      def campaign_params
        params.fetch(:campaign, params).permit(
          :name, :subject, :from_name, :from_email, :body_html, :body_text, :campaign_type, settings: {}
        )
      end

      def parse_scheduled_at
        return nil if params[:scheduled_at].blank?
        Time.iso8601(params[:scheduled_at].to_s)
      rescue ArgumentError
        nil
      end

      def render_already_finalized
        render_error(code: "invalid_state", message: "Campaign has already been sent or is sending", status: :unprocessable_entity)
      end
    end
  end
end
