module Api
  module V1
    class WebhookDeliveriesController < BaseController
      before_action :set_delivery, only: [ :replay ]

      def replay
        unless @delivery.replayable?
          render json: { error: "only failed deliveries can be replayed" }, status: :unprocessable_entity
          return
        end

        @delivery.update!(status: "pending", last_error_message: nil)
        DeliverWebhookJob.perform_later(@delivery.id)
        render json: { id: @delivery.id, status: @delivery.status }, status: :accepted
      end

      private

      def set_delivery
        @delivery = WebhookDelivery
          .joins(:webhook_endpoint)
          .where(webhook_endpoints: { account_id: current_account.id })
          .find(params[:id])
      end
    end
  end
end
