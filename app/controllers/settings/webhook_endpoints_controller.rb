module Settings
  class WebhookEndpointsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_endpoint, only: [ :show, :edit, :update, :destroy, :test_fire ]

    def index
      @endpoints = current_account.webhook_endpoints.order(created_at: :desc)
    end

    def show
      @recent_deliveries = @endpoint.webhook_deliveries.recent.limit(50)
    end

    def new
      @endpoint = current_account.webhook_endpoints.build(active: true, event_types: [])
    end

    def create
      @endpoint = current_account.webhook_endpoints.build(endpoint_params)

      if @endpoint.save
        flash[:webhook_secret] = @endpoint.secret
        redirect_to settings_webhook_endpoint_path(@endpoint), notice: "Webhook endpoint created. Copy the signing secret now; it will not be shown again."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @endpoint.update(endpoint_params)
        redirect_to settings_webhook_endpoint_path(@endpoint), notice: "Webhook endpoint updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @endpoint.destroy
      redirect_to settings_webhook_endpoints_path, notice: "Webhook endpoint removed."
    end

    def test_fire
      Webhooks::Dispatcher.dispatch(
        account: current_account,
        event_type: "webhook.test",
        data: Webhooks::PayloadSerializer.test_event
      )
      redirect_to settings_webhook_endpoint_path(@endpoint), notice: "Test event queued."
    end

    private

    def current_account
      current_user.account
    end

    def set_endpoint
      @endpoint = current_account.webhook_endpoints.find(params[:id])
    end

    def endpoint_params
      permitted = params.require(:webhook_endpoint).permit(:url, :active, event_types: [])
      permitted[:event_types] = Array(permitted[:event_types]).reject(&:blank?)
      permitted
    end
  end
end
