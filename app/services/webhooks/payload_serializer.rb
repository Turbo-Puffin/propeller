module Webhooks
  # Builds the `data` block for each event type. Kept small and explicit so the
  # JSON shape on the wire is auditable from one file.
  module PayloadSerializer
    module_function

    def contact(contact, source: nil)
      {
        "id" => contact.id,
        "email" => contact.email,
        "first_name" => contact.first_name,
        "last_name" => contact.last_name,
        "status" => contact.status,
        "metadata" => contact.metadata,
        "subscribed_at" => contact.subscribed_at&.utc&.iso8601,
        "unsubscribed_at" => contact.unsubscribed_at&.utc&.iso8601,
        "source" => source,
        "created_at" => contact.created_at.utc.iso8601,
        "updated_at" => contact.updated_at.utc.iso8601
      }.compact
    end

    def contact_list(list)
      {
        "id" => list.id,
        "name" => list.name,
        "description" => list.description,
        "auto_segment_rules" => list.auto_segment_rules,
        "created_at" => list.created_at.utc.iso8601,
        "updated_at" => list.updated_at.utc.iso8601
      }
    end

    def campaign(campaign)
      {
        "id" => campaign.id,
        "name" => campaign.name,
        "subject" => campaign.subject,
        "status" => campaign.status,
        "campaign_type" => campaign.campaign_type,
        "scheduled_at" => campaign.scheduled_at&.utc&.iso8601,
        "sent_at" => campaign.sent_at&.utc&.iso8601,
        "from_email" => campaign.from_email,
        "from_name" => campaign.from_name,
        "created_at" => campaign.created_at.utc.iso8601,
        "updated_at" => campaign.updated_at.utc.iso8601
      }
    end

    def segment_evaluation(segment_id:, matching_count:, duration_ms:)
      {
        "segment_id" => segment_id,
        "matching_count" => matching_count,
        "duration_ms" => duration_ms
      }
    end

    def test_event
      {
        "message" => "This is a test event from Propeller.",
        "fired_at" => Time.current.utc.iso8601
      }
    end
  end
end
