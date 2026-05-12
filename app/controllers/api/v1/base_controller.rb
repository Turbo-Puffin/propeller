module Api
  module V1
    class BaseController < ActionController::API
      include ApiAuthenticatable

      MAX_PER_PAGE = 100
      DEFAULT_PER_PAGE = 25

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      private

      def render_error(code:, message:, status:, fields: nil)
        payload = { code: code, message: message }
        payload[:fields] = fields if fields
        render json: { error: payload }, status: status
      end

      def render_not_found(_exception = nil)
        render_error(code: "not_found", message: "Resource not found", status: :not_found)
      end

      def render_parameter_missing(exception)
        render_error(
          code: "validation_failed",
          message: exception.message,
          status: :bad_request
        )
      end

      def render_validation_errors(record)
        fields = record.errors.messages.transform_values { |msgs| msgs.map(&:to_s) }
        render_error(
          code: "validation_failed",
          message: record.errors.full_messages.first || "Validation failed",
          status: :unprocessable_entity,
          fields: fields
        )
      end

      def pagination_params
        page = params[:page].to_i
        page = 1 if page < 1
        per_page = params[:per_page].to_i
        per_page = DEFAULT_PER_PAGE if per_page <= 0
        per_page = MAX_PER_PAGE if per_page > MAX_PER_PAGE
        [ page, per_page ]
      end

      def paginate(scope)
        page, per_page = pagination_params
        scope.limit(per_page).offset((page - 1) * per_page)
      end

      def meta_for(scope)
        page, per_page = pagination_params
        total = scope.count
        {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      end
    end
  end
end
