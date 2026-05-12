module Api
  module V1
    class ContactsController < BaseController
      before_action :set_contact, only: [ :show, :update, :destroy ]

      def index
        scope = current_account.contacts.order(created_at: :desc)
        render json: {
          data: paginate(scope).map { |c| ContactSerializer.serialize(c) },
          meta: meta_for(scope)
        }
      end

      def show
        render json: { data: ContactSerializer.serialize(@contact) }
      end

      def create
        contact = current_account.contacts.new(contact_params)
        if contact.save
          render json: { data: ContactSerializer.serialize(contact) }, status: :created
        else
          render_validation_errors(contact)
        end
      end

      def update
        if @contact.update(contact_params)
          render json: { data: ContactSerializer.serialize(@contact) }
        else
          render_validation_errors(@contact)
        end
      end

      def destroy
        @contact.destroy!
        head :no_content
      end

      private

      def set_contact
        @contact = current_account.contacts.find(params[:id])
      end

      def contact_params
        params.fetch(:contact, params).permit(
          :email, :first_name, :last_name, :status, metadata: {}
        )
      end
    end
  end
end
