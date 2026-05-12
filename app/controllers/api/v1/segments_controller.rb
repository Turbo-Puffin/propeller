module Api
  module V1
    class SegmentsController < BaseController
      before_action :set_segment, only: [ :show, :update, :destroy, :contacts ]

      def index
        scope = current_account.segments.order(created_at: :desc)
        scope = scope.where(contact_list_id: params[:list_id]) if params[:list_id].present?
        render json: {
          data: paginate(scope).map { |s| SegmentSerializer.serialize(s) },
          meta: meta_for(scope)
        }
      end

      def show
        render json: { data: SegmentSerializer.serialize(@segment, include_count: true) }
      end

      def create
        segment = current_account.segments.new(segment_params)
        if segment.save
          render json: { data: SegmentSerializer.serialize(segment, include_count: true) }, status: :created
        else
          render_validation_errors(segment)
        end
      end

      def update
        if @segment.update(segment_params.except(:contact_list_id))
          render json: { data: SegmentSerializer.serialize(@segment, include_count: true) }
        else
          render_validation_errors(@segment)
        end
      end

      def destroy
        @segment.destroy!
        head :no_content
      end

      def contacts
        scope = @segment.matching_scope.order(:email)
        render json: {
          data: paginate(scope).map { |c| ContactSerializer.serialize(c) },
          meta: meta_for(scope)
        }
      end

      private

      def set_segment
        @segment = current_account.segments.find(params[:id])
      end

      def segment_params
        source = params.fetch(:segment, params)
        list_id = source[:contact_list_id].presence || source[:list_id].presence
        validate_contact_list!(list_id)

        attrs = {}
        attrs[:name] = source[:name] if source[:name].present?
        attrs[:contact_list_id] = list_id if list_id
        attrs[:rules] = deep_unwrap(source[:rules]) if source.key?(:rules)
        attrs
      end

      def deep_unwrap(value)
        case value
        when ActionController::Parameters then value.to_unsafe_h
        when Hash                          then value
        else value
        end
      end

      def validate_contact_list!(list_id)
        return if list_id.blank?
        return if current_account.contact_lists.exists?(id: list_id)
        raise ActiveRecord::RecordNotFound, "Contact list not found"
      end
    end
  end
end
