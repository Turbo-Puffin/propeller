module Api
  module V1
    module SendSerializer
      module_function

      def serialize(record)
        {
          id: record.id,
          campaign_id: record.campaign_id,
          contact_id: record.contact_id,
          status: record.status,
          sent_at: record.sent_at&.iso8601,
          opened_at: record.opened_at&.iso8601,
          clicked_at: record.clicked_at&.iso8601,
          bounced_at: record.bounced_at&.iso8601,
          created_at: record.created_at.iso8601,
          updated_at: record.updated_at.iso8601
        }
      end
    end
  end
end
