module Settings
  class ApiKeysController < ApplicationController
    before_action :authenticate_user!

    def index
      @api_keys = current_user.account.api_keys.active.order(created_at: :desc)
      @new_key = flash[:new_api_key]
    end

    def create
      name = params[:name].to_s.strip
      environment = params[:environment].to_s.presence || "live"

      if name.blank?
        flash[:alert] = "Please give the key a name."
        redirect_to settings_api_keys_path and return
      end

      unless ApiKey::ENVIRONMENTS.include?(environment)
        flash[:alert] = "Environment must be live or test."
        redirect_to settings_api_keys_path and return
      end

      api_key = ApiKey.generate!(account: current_user.account, name: name, environment: environment)
      flash[:new_api_key] = { "id" => api_key.id, "name" => api_key.name, "plaintext" => api_key.plaintext_key }
      flash[:notice] = "API key created. Copy it now; it will not be shown again."
      redirect_to settings_api_keys_path
    end

    def destroy
      api_key = current_user.account.api_keys.find(params[:id])
      api_key.revoke!
      flash[:notice] = "API key revoked."
      redirect_to settings_api_keys_path
    end
  end
end
