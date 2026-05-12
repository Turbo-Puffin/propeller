module Services
  # Evaluates a Segment's rule set against contacts. Two entry points:
  #
  #   matches?(contact) - boolean for a single contact, evaluated in Ruby.
  #   matching_scope    - ActiveRecord::Relation of every matching contact in the
  #                       segment's account, pushed to SQL where each operator can be
  #                       expressed cleanly, with Ruby fallback for the few that can't.
  #
  # Engagement operators (opened_within_days, etc.) are wired but permissive in v1:
  # they evaluate true for everyone until campaign-send event data lands.
  class SegmentEvaluator
    OPERATORS = %w[
      equals not_equals starts_with ends_with contains matches_regex
      greater_than less_than before after between
      in_list not_in_list
      includes excludes any_of all_of
      opened_within_days not_opened_within_days clicked_within_days
    ].freeze

    ENGAGEMENT_OPS = %w[opened_within_days not_opened_within_days clicked_within_days].freeze

    DIRECT_COLUMNS = %w[
      email first_name last_name status
      subscribed_at unsubscribed_at created_at updated_at
    ].freeze

    DATE_COLUMNS = %w[subscribed_at unsubscribed_at created_at updated_at].freeze
    TAGS_KEY = "tags".freeze

    def initialize(segment)
      @segment = segment
    end

    def matches?(contact)
      rules = @segment.rule_list
      return true if rules.empty?

      method = @segment.match_mode == "all" ? :all? : :any?
      rules.send(method) { |r| evaluate_in_memory(r, contact) }
    end

    def matching_scope
      base = Contact.where(account_id: @segment.account_id)
      base = base.where(id: @segment.contact_list.contacts.select(:id)) if @segment.contact_list_id.present?

      rules = @segment.rule_list
      return base if rules.empty?

      sql_rules, ruby_rules = rules.partition { |r| sql_compilable?(r) }
      mode = @segment.match_mode

      base = apply_sql_rules(base, sql_rules, mode)
      base = apply_ruby_fallback(base, ruby_rules, mode) if ruby_rules.any?
      base
    end

    private

    def evaluate_in_memory(rule, contact)
      op = rule["op"]
      return true if ENGAGEMENT_OPS.include?(op)

      property_value = property_value_for(contact, rule["property"])
      rule_value = rule["value"]

      case op
      when "equals"            then values_equal?(property_value, rule_value)
      when "not_equals"        then !values_equal?(property_value, rule_value)
      when "starts_with"       then property_value.to_s.start_with?(rule_value.to_s)
      when "ends_with"         then property_value.to_s.end_with?(rule_value.to_s)
      when "contains"          then property_value.to_s.include?(rule_value.to_s)
      when "matches_regex"     then safe_regex_match?(rule_value, property_value)
      when "greater_than"      then numeric_compare(property_value, rule_value, :>)
      when "less_than"         then numeric_compare(property_value, rule_value, :<)
      when "before"            then date_compare(property_value, rule_value, :<)
      when "after"             then date_compare(property_value, rule_value, :>)
      when "between"           then between_compare(property_value, rule_value)
      when "in_list"           then contact_in_list?(contact, rule_value)
      when "not_in_list"       then !contact_in_list?(contact, rule_value)
      when "includes"          then Array(property_value).map(&:to_s).include?(rule_value.to_s)
      when "excludes"          then !Array(property_value).map(&:to_s).include?(rule_value.to_s)
      when "any_of"            then (Array(property_value).map(&:to_s) & Array(rule_value).map(&:to_s)).any?
      when "all_of"            then (Array(rule_value).map(&:to_s) - Array(property_value).map(&:to_s)).empty?
      else
        false
      end
    end

    def property_value_for(contact, property)
      return nil if property.blank?

      case property
      when "tag", "tags"
        Array((contact.metadata || {})[TAGS_KEY])
      else
        if property.start_with?("metadata.")
          key = property.sub(/\Ametadata\./, "")
          (contact.metadata || {})[key]
        elsif DIRECT_COLUMNS.include?(property)
          contact.public_send(property)
        else
          (contact.metadata || {})[property]
        end
      end
    end

    def values_equal?(a, b)
      return a == b if a.is_a?(Numeric) && b.is_a?(Numeric)
      a.to_s == b.to_s
    end

    def numeric_compare(a, b, op)
      a_f = Float(a, exception: false)
      b_f = Float(b, exception: false)
      return false if a_f.nil? || b_f.nil?
      a_f.public_send(op, b_f)
    end

    def date_compare(a, b, op)
      a_t = coerce_time(a)
      b_t = coerce_time(b)
      return false if a_t.nil? || b_t.nil?
      a_t.public_send(op, b_t)
    end

    def between_compare(value, range)
      return false unless range.is_a?(Array) && range.length == 2
      low, high = range
      low_t = coerce_time(low) || Float(low, exception: false)
      high_t = coerce_time(high) || Float(high, exception: false)
      value_t = coerce_time(value) || Float(value, exception: false)
      return false if [ low_t, high_t, value_t ].any?(&:nil?)
      value_t >= low_t && value_t <= high_t
    end

    def coerce_time(value)
      return nil if value.nil?
      return value if value.is_a?(Time) || value.is_a?(DateTime)
      return value.to_time if value.is_a?(Date)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def safe_regex_match?(pattern, value)
      Regexp.new(pattern.to_s).match?(value.to_s)
    rescue RegexpError
      false
    end

    def contact_in_list?(contact, list_id)
      contact.contact_list_memberships.exists?(contact_list_id: list_id)
    end

    def sql_compilable?(rule)
      return false if rule["op"].blank?
      return true if ENGAGEMENT_OPS.include?(rule["op"]) # permissive: emit no-op
      property = rule["property"].to_s
      return true if property == "tag" || property == "tags"
      return true if property.start_with?("metadata.")
      return true if DIRECT_COLUMNS.include?(property)
      false
    end

    def apply_sql_rules(scope, sql_rules, mode)
      return scope if sql_rules.empty?

      predicates = sql_rules.map { |r| arel_for(r) }.compact
      return scope if predicates.empty?

      combined = mode == "all" ? predicates.reduce(:and) : predicates.reduce(:or)
      scope.where(combined)
    end

    def apply_ruby_fallback(scope, ruby_rules, mode)
      method = mode == "all" ? :all? : :any?
      matching_ids = scope.find_each.select do |contact|
        ruby_rules.send(method) { |r| evaluate_in_memory(r, contact) }
      end.map(&:id)
      Contact.where(id: matching_ids)
    end

    def arel_for(rule)
      op = rule["op"]
      return Arel.sql("TRUE") if ENGAGEMENT_OPS.include?(op)

      property = rule["property"].to_s
      value = rule["value"]
      arel_node, value_type = column_node_for(property)
      return nil unless arel_node

      case op
      when "equals"        then build_equality(arel_node, value, value_type, negate: false)
      when "not_equals"    then build_equality(arel_node, value, value_type, negate: true)
      when "starts_with"   then arel_node.matches("#{escape_like(value.to_s)}%")
      when "ends_with"     then arel_node.matches("%#{escape_like(value.to_s)}")
      when "contains"      then arel_node.matches("%#{escape_like(value.to_s)}%")
      when "matches_regex" then Arel::Nodes::InfixOperation.new("~", arel_node, Arel::Nodes::Quoted.new(value.to_s))
      when "greater_than"  then arel_node.gt(value)
      when "less_than"     then arel_node.lt(value)
      when "before"        then arel_node.lt(coerce_time(value))
      when "after"         then arel_node.gt(coerce_time(value))
      when "between"       then build_between(arel_node, value, value_type)
      when "in_list"       then in_list_predicate(value, negate: false)
      when "not_in_list"   then in_list_predicate(value, negate: true)
      when "includes"      then jsonb_array_contains(property, value)
      when "excludes"      then Arel::Nodes::Not.new(jsonb_array_contains(property, value))
      when "any_of"        then jsonb_array_any_of(property, value)
      when "all_of"        then jsonb_array_all_of(property, value)
      end
    end

    def column_node_for(property)
      table = Contact.arel_table

      if property == "tag" || property == "tags"
        # The jsonb array lookups go through dedicated helpers; return a sentinel
        # so the caller knows this is a tag-style property.
        [ table[:metadata], :tags ]
      elsif property.start_with?("metadata.")
        key = property.sub(/\Ametadata\./, "")
        node = Arel::Nodes::InfixOperation.new("->>", table[:metadata], Arel::Nodes::Quoted.new(key))
        [ node, :text ]
      elsif DATE_COLUMNS.include?(property)
        [ table[property.to_sym], :time ]
      elsif DIRECT_COLUMNS.include?(property)
        [ table[property.to_sym], :text ]
      else
        [ nil, nil ]
      end
    end

    def build_equality(node, value, value_type, negate:)
      coerced = value_type == :time ? coerce_time(value) : value
      predicate = node.eq(coerced)
      negate ? Arel::Nodes::Not.new(predicate) : predicate
    end

    def build_between(node, value, value_type)
      return Arel.sql("FALSE") unless value.is_a?(Array) && value.length == 2
      low, high = value
      if value_type == :time
        low = coerce_time(low)
        high = coerce_time(high)
        return Arel.sql("FALSE") if low.nil? || high.nil?
      end
      node.gteq(low).and(node.lteq(high))
    end

    def in_list_predicate(list_id, negate:)
      memberships = ContactListMembership.arel_table
      subquery = memberships
        .project(memberships[:contact_id])
        .where(memberships[:contact_list_id].eq(list_id))

      predicate = Contact.arel_table[:id].in(subquery)
      negate ? Arel::Nodes::Not.new(predicate) : predicate
    end

    def escape_like(string)
      string.gsub(/[\\%_]/) { |c| "\\#{c}" }
    end

    def jsonb_array_contains(property, value)
      key = property == "tag" ? TAGS_KEY : (property == "tags" ? TAGS_KEY : property.sub(/\Ametadata\./, ""))
      left = Arel::Nodes::InfixOperation.new("->", Contact.arel_table[:metadata], Arel::Nodes::Quoted.new(key))
      Arel::Nodes::InfixOperation.new("?", left, Arel::Nodes::Quoted.new(value.to_s))
    end

    def jsonb_array_any_of(property, values)
      Array(values).map { |v| jsonb_array_contains(property, v) }.reduce(:or) || Arel.sql("FALSE")
    end

    def jsonb_array_all_of(property, values)
      Array(values).map { |v| jsonb_array_contains(property, v) }.reduce(:and) || Arel.sql("TRUE")
    end
  end
end
