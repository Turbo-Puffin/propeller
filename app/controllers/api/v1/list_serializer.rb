module Api
  module V1
    module ListSerializer
      module_function

      def serialize(list)
        {
          id: list.id,
          name: list.name,
          description: list.description,
          contact_count: list.contacts.count,
          created_at: list.created_at.iso8601,
          updated_at: list.updated_at.iso8601
        }
      end
    end
  end
end
