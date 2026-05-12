module Api
  module V1
    class WebhookEndpointsController < BaseController
      before_action :set_endpoint, only: [ :show, :update, :destroy, :deliveries, :test_fire ]

      def index
        endpoints = current_account.webhook_endpoints.order(created_at: :desc)
        render json: endpoints.map { |e| serialize_endpoint(e) }
      end

      def show
        render json: serialize_endpoint(@endpoint)
      end

      def create
        endpoint = current_account.webhook_endpoints.build(create_params)
        endpoint.save!
        render json: serialize_endpoint(endpoint).merge("secret" => endpoint.secret),
               status: :created
      end

      def update
        @endpoint.update!(update_params)
        render json: serialize_endpoint(@endpoint)
      end

      def destroy
        @endpoint.destroy!
        head :no_content
      end

      def deliveries
        deliveries = @endpoint.webhook_deliveries.recent.limit(100)
        render json: deliveries.map { |d| serialize_delivery(d) }
      end

      def test_fire
        Webhooks::Dispatcher.dispatch(
          account: current_account,
          event_type: "webhook.test",
          data: Webhooks::PayloadSerializer.test_event
        )
        head :accepted
      end

      private

      def set_endpoint
        @endpoint = current_account.webhook_endpoints.find(params[:id])
      end

      def create_params
        params.permit(:url, :active, event_types: [])
      end

      def update_params
        params.permit(:url, :active, event_types: [])
      end

      def serialize_endpoint(endpoint)
        {
          "id" => endpoint.id,
          "url" => endpoint.url,
          "event_types" => endpoint.event_types,
          "active" => endpoint.active,
          "secret_preview" => endpoint.secret_preview,
          "last_success_at" => endpoint.last_success_at&.utc&.iso8601,
          "last_failure_at" => endpoint.last_failure_at&.utc&.iso8601,
          "last_failure_message" => endpoint.last_failure_message,
          "created_at" => endpoint.created_at.utc.iso8601,
          "updated_at" => endpoint.updated_at.utc.iso8601
        }
      end

      def serialize_delivery(delivery)
        {
          "id" => delivery.id,
          "event_type" => delivery.event_type,
          "status" => delivery.status,
          "attempts" => delivery.attempts,
          "response_status" => delivery.response_status,
          "delivered_at" => delivery.delivered_at&.utc&.iso8601,
          "last_error_message" => delivery.last_error_message,
          "created_at" => delivery.created_at.utc.iso8601
        }
      end
    end
  end
end
