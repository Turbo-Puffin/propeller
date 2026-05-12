class Segment < ApplicationRecord
  belongs_to :account
  belongs_to :contact_list, optional: true

  validates :name, presence: true
  validate :rules_must_be_well_formed

  def matches?(contact)
    Services::SegmentEvaluator.new(self).matches?(contact)
  end

  def matching_scope
    Services::SegmentEvaluator.new(self).matching_scope
  end

  def matching_count
    matching_scope.count
  end

  def match_mode
    (rules.is_a?(Hash) ? rules["match"] : nil).to_s == "any" ? "any" : "all"
  end

  def rule_list
    return [] unless rules.is_a?(Hash)
    Array(rules["rules"])
  end

  private

  def rules_must_be_well_formed
    return errors.add(:rules, "must be a JSON object") unless rules.is_a?(Hash)

    match_value = rules["match"]
    if match_value.present? && !%w[all any].include?(match_value.to_s)
      errors.add(:rules, "match must be 'all' or 'any'")
    end

    rule_entries = rules["rules"]
    if rule_entries && !rule_entries.is_a?(Array)
      errors.add(:rules, "rules must be an array")
      return
    end

    Array(rule_entries).each_with_index do |entry, idx|
      unless entry.is_a?(Hash)
        errors.add(:rules, "rule ##{idx + 1} must be an object")
        next
      end
      errors.add(:rules, "rule ##{idx + 1} is missing 'property'") if entry["property"].blank?
      op = entry["op"]
      if op.blank?
        errors.add(:rules, "rule ##{idx + 1} is missing 'op'")
      elsif Services::SegmentEvaluator::OPERATORS.exclude?(op)
        errors.add(:rules, "rule ##{idx + 1} has unknown op '#{op}'")
      end
    end
  end
end
