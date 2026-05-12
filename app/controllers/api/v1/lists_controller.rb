module Api
  module V1
    class ListsController < BaseController
      before_action :set_list, only: [ :show, :add_contact, :remove_contact ]

      def index
        scope = current_account.contact_lists.order(created_at: :desc)
        render json: {
          data: paginate(scope).map { |l| ListSerializer.serialize(l) },
          meta: meta_for(scope)
        }
      end

      def show
        render json: { data: ListSerializer.serialize(@list) }
      end

      def create
        list = current_account.contact_lists.new(list_params)
        if list.save
          render json: { data: ListSerializer.serialize(list) }, status: :created
        else
          render_validation_errors(list)
        end
      end

      def add_contact
        contact = current_account.contacts.find(params[:contact_id])
        membership = @list.contact_list_memberships.find_or_initialize_by(contact: contact)
        if membership.persisted? || membership.save
          render json: { data: ListSerializer.serialize(@list.reload) }, status: :created
        else
          render_validation_errors(membership)
        end
      end

      def remove_contact
        contact = current_account.contacts.find(params[:contact_id])
        membership = @list.contact_list_memberships.find_by(contact: contact)
        return render_error(code: "not_found", message: "Contact is not on this list", status: :not_found) unless membership
        membership.destroy!
        head :no_content
      end

      private

      def set_list
        @list = current_account.contact_lists.find(params[:id])
      end

      def list_params
        params.fetch(:list, params).permit(:name, :description, auto_segment_rules: {})
      end
    end
  end
end
