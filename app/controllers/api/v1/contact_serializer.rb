module Api
  module V1
    module ContactSerializer
      module_function

      def serialize(contact)
        {
          id: contact.id,
          email: contact.email,
          first_name: contact.first_name,
          last_name: contact.last_name,
          status: contact.status,
          metadata: contact.metadata || {},
          subscribed_at: contact.subscribed_at&.iso8601,
          unsubscribed_at: contact.unsubscribed_at&.iso8601,
          created_at: contact.created_at.iso8601,
          updated_at: contact.updated_at.iso8601
        }
      end
    end
  end
end
