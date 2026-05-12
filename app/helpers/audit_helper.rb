module AuditHelper
  def actor_badge_class(actor_type)
    case actor_type
    when "User"   then "bg-emerald-500/15 text-emerald-300 border border-emerald-500/30"
    when "ApiKey" then "bg-violet-500/15 text-violet-300 border border-violet-500/30"
    when "System" then "bg-gray-500/15 text-gray-300 border border-gray-500/30"
    else "bg-gray-500/15 text-gray-300 border border-gray-500/30"
    end
  end
end
