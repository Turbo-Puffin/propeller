class TemplateRenderer
  Result = Struct.new(:subject, :html, :plain, :errors, keyword_init: true) do
    def success?
      errors.empty?
    end
  end

  def initialize(template:, contact: nil, campaign: nil)
    @template = template
    @contact = contact
    @campaign = campaign
    @account = template.account
    @errors = []
  end

  def call
    Result.new(
      subject: render_source(@template.subject_template),
      html: render_source(@template.html_body),
      plain: render_source(plain_source),
      errors: @errors
    )
  end

  def self.render(template:, contact: nil, campaign: nil)
    new(template: template, contact: contact, campaign: campaign).call
  end

  private

  def plain_source
    return @template.plain_body if @template.plain_body.present?

    EmailTemplate.derive_plain_body_from(@template.html_body.to_s)
  end

  def render_source(source)
    return "" if source.blank?

    parsed = Liquid::Template.parse(source, error_mode: :strict)
    parsed.render!(assigns, registers: {}, strict_variables: false, strict_filters: false)
  rescue Liquid::Error => e
    @errors << e.message
    ""
  end

  def assigns
    @assigns ||= begin
      contact_h = contact_hash
      campaign_h = campaign_hash
      account_h = account_hash
      defaults = stringify(@template.default_variables)

      flat = defaults.merge(account_h).merge(campaign_h).merge(contact_h)

      flat.merge(
        "contact" => contact_h,
        "campaign" => campaign_h,
        "account" => account_h,
        "defaults" => defaults
      )
    end
  end

  def contact_hash
    return {} unless @contact

    base = {
      "id" => @contact.id,
      "email" => @contact.email,
      "first_name" => @contact.first_name,
      "last_name" => @contact.last_name,
      "status" => @contact.status
    }
    base.merge(stringify(@contact.try(:metadata)))
  end

  def campaign_hash
    return {} unless @campaign

    {
      "id" => @campaign.id,
      "name" => @campaign.name,
      "subject" => @campaign.subject,
      "from_name" => @campaign.from_name,
      "from_email" => @campaign.from_email,
      "scheduled_at" => @campaign.scheduled_at,
      "sent_at" => @campaign.sent_at
    }
  end

  def account_hash
    {
      "id" => @account.id,
      "name" => @account.name,
      "subdomain" => @account.subdomain
    }.merge(stringify(@account.try(:settings)))
  end

  def stringify(hash)
    return {} unless hash.is_a?(Hash)

    hash.deep_stringify_keys
  end
end
