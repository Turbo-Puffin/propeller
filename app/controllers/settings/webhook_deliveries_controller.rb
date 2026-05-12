module Settings
  class WebhookDeliveriesController < ApplicationController
    before_action :authenticate_user!

    def index
      endpoint = current_account.webhook_endpoints.find(params[:webhook_endpoint_id])
      @endpoint = endpoint
      @deliveries = endpoint.webhook_deliveries.recent.limit(100)
      render "settings/webhook_endpoints/deliveries"
    end

    def replay
      delivery = WebhookDelivery
        .joins(:webhook_endpoint)
        .where(webhook_endpoints: { account_id: current_account.id })
        .find(params[:id])

      unless delivery.replayable?
        redirect_back(fallback_location: settings_webhook_endpoint_path(delivery.webhook_endpoint),
                      alert: "Only failed deliveries can be replayed.")
        return
      end

      delivery.update!(status: "pending", last_error_message: nil)
      DeliverWebhookJob.perform_later(delivery.id)
      redirect_back(fallback_location: settings_webhook_endpoint_path(delivery.webhook_endpoint),
                    notice: "Delivery queued for replay.")
    end

    private

    def current_account
      current_user.account
    end
  end
end
