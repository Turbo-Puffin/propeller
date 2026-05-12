class EmailTemplate < ApplicationRecord
  STATUSES = %w[active archived].freeze

  belongs_to :account

  validates :name, presence: true
  validates :slug, presence: true,
            uniqueness: { scope: :account_id, case_sensitive: false },
            format: { with: /\A[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?\z/, message: "must be lowercase alphanumeric with hyphens or underscores" }
  validates :html_body, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :default_variables_is_hash
  validate :liquid_syntax_valid

  before_validation :normalize_slug
  before_validation :derive_plain_body, if: -> { plain_body.blank? && html_body.present? }

  scope :active, -> { where(status: "active") }
  scope :archived, -> { where(status: "archived") }

  def archived?
    status == "archived"
  end

  def active?
    status == "active"
  end

  def archive!
    update!(status: "archived")
  end

  def unarchive!
    update!(status: "active")
  end

  def to_param
    slug
  end

  def self.find_by_id_or_slug!(account, id_or_slug)
    scope = account.email_templates
    if id_or_slug.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      scope.find(id_or_slug)
    else
      scope.find_by!(slug: id_or_slug.to_s.downcase)
    end
  end

  def self.derive_plain_body_from(html)
    return "" if html.blank?

    text = html.dup
    text.gsub!(/<br\s*\/?>/i, "\n")
    text.gsub!(/<\/(p|div|h[1-6]|li|tr)>/i, "\n")
    text.gsub!(/<[^>]+>/, "")
    text = CGI.unescapeHTML(text)
    text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
  end

  private

  def normalize_slug
    self.slug = slug.to_s.downcase.strip if slug.present?
    self.slug = name.to_s.parameterize if slug.blank? && name.present?
  end

  def derive_plain_body
    self.plain_body = self.class.derive_plain_body_from(html_body)
  end

  def default_variables_is_hash
    return if default_variables.is_a?(Hash)

    errors.add(:default_variables, "must be a JSON object")
  end

  def liquid_syntax_valid
    [ [ :subject_template, subject_template ], [ :html_body, html_body ], [ :plain_body, plain_body ] ].each do |field, source|
      next if source.blank?

      Liquid::Template.parse(source, error_mode: :strict)
    rescue Liquid::SyntaxError => e
      errors.add(field, "has invalid Liquid syntax: #{e.message}")
    end
  end
end
