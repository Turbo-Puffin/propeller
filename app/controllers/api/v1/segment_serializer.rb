module Api
  module V1
    module SegmentSerializer
      module_function

      def serialize(segment, include_count: false)
        payload = {
          id: segment.id,
          name: segment.name,
          contact_list_id: segment.contact_list_id,
          rules: segment.rules || { "match" => "all", "rules" => [] },
          created_at: segment.created_at.iso8601,
          updated_at: segment.updated_at.iso8601
        }
        payload[:matching_count] = segment.matching_count if include_count
        payload
      end
    end
  end
end
