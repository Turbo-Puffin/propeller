module Api
  module V1
    class BaseController < ApplicationController
      skip_forgery_protection

      before_action :authenticate_api_user!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid

      private

      def authenticate_api_user!
        return if current_user.present?

        render json: { error: "unauthorized" }, status: :unauthorized
      end

      def current_account
        current_user&.account
      end

      def render_not_found
        render json: { error: "not_found" }, status: :not_found
      end

      def render_invalid(exception)
        render json: { error: "invalid", details: exception.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
