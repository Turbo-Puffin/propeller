module Api
  module V1
    module CampaignSerializer
      module_function

      def serialize(campaign)
        {
          id: campaign.id,
          name: campaign.name,
          subject: campaign.subject,
          from_name: campaign.from_name,
          from_email: campaign.from_email,
          status: campaign.status,
          campaign_type: campaign.campaign_type,
          scheduled_at: campaign.scheduled_at&.iso8601,
          sent_at: campaign.sent_at&.iso8601,
          created_at: campaign.created_at.iso8601,
          updated_at: campaign.updated_at.iso8601
        }
      end
    end
  end
end
