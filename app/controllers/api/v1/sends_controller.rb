module Api
  module V1
    class SendsController < BaseController
      def index
        scope = base_scope.order(created_at: :desc)
        scope = scope.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
        scope = scope.where(contact_id: params[:contact_id]) if params[:contact_id].present?
        render json: {
          data: paginate(scope).map { |s| SendSerializer.serialize(s) },
          meta: meta_for(scope)
        }
      end

      def show
        send_record = base_scope.find(params[:id])
        render json: { data: SendSerializer.serialize(send_record) }
      end

      private

      def base_scope
        CampaignSend.joins(:campaign).where(campaigns: { account_id: current_account.id })
      end
    end
  end
end
