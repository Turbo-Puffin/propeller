require "test_helper"

class TemplateRendererTest < ActiveSupport::TestCase
  test "renders subject, html, plain with contact properties" do
    account = create_account
    contact = create_contact(account: account, first_name: "Ada", last_name: "Lovelace")
    template = create_template(account: account,
      subject_template: "Hi {{ contact.first_name }}",
      html_body: "<p>Hello {{ contact.first_name }} {{ contact.last_name }}!</p>",
      plain_body: "Hello {{ contact.first_name }}!")

    result = TemplateRenderer.render(template: template, contact: contact)

    assert result.success?
    assert_equal "Hi Ada", result.subject
    assert_equal "<p>Hello Ada Lovelace!</p>", result.html
    assert_equal "Hello Ada!", result.plain
  end

  test "resolves variables in priority order contact > campaign > account > defaults" do
    account = create_account
    account.update!(settings: { "tagline" => "from-account" })
    contact = create_contact(account: account, metadata: { "tagline" => "from-contact" })
    campaign = Campaign.create!(account: account, name: "Promo")
    # Inject a campaign-level tagline by passing it through a campaign hash override is not supported;
    # tagline lives on contact (priority 1) above campaign and account.
    template = create_template(account: account,
      subject_template: "{{ tagline }}",
      html_body: "<p>{{ tagline }}</p>",
      plain_body: "{{ tagline }}",
      default_variables: { "tagline" => "from-defaults" })

    # contact wins
    assert_equal "from-contact", TemplateRenderer.render(template: template, contact: contact, campaign: campaign).subject

    # without contact, account wins over defaults
    assert_equal "from-account", TemplateRenderer.render(template: template, contact: nil, campaign: campaign).subject

    # without account override, defaults win
    account.update!(settings: {})
    assert_equal "from-defaults", TemplateRenderer.render(template: template, contact: nil, campaign: nil).subject
  end

  test "missing variables fall through to default_variables, then to empty string" do
    account = create_account
    template = create_template(account: account,
      subject_template: "Hi {{ first_name }} / {{ promo_code }}",
      html_body: "<p>{{ promo_code }} / {{ unknown_thing }}</p>",
      plain_body: "{{ unknown_thing }}",
      default_variables: { "promo_code" => "SUMMER20" })

    result = TemplateRenderer.render(template: template, contact: nil)

    assert result.success?
    assert_equal "Hi  / SUMMER20", result.subject
    assert_equal "<p>SUMMER20 / </p>", result.html
    assert_equal "", result.plain
  end

  test "malformed Liquid surfaces a meaningful error and does not raise" do
    account = create_account
    template = create_template(account: account, html_body: "<p>ok</p>", subject_template: "fine")
    # Force a malformed source by writing directly past validations.
    template.update_column(:html_body, "<p>{% if %}</p>")

    result = nil
    assert_nothing_raised do
      result = TemplateRenderer.render(template: template, contact: nil)
    end
    refute result.success?
    assert result.errors.any?, "expected at least one error"
    assert(result.errors.any? { |e| e.match?(/if|tag|syntax/i) })
  end

  test "Liquid is sandboxed: include tag does not read arbitrary files" do
    account = create_account
    template = create_template(account: account, html_body: "<p>ok</p>")
    template.update_column(:html_body, "{% include 'something_dangerous' %}")

    result = TemplateRenderer.render(template: template, contact: nil)
    # Liquid's default BlankFileSystem raises a Liquid::FileSystemError -> captured in errors.
    refute result.success?
    assert_equal "", result.html
    assert(result.errors.any? { |e| e.match?(/file system|include/i) })
  end

  test "contact metadata keys are accessible at the top level and namespaced" do
    account = create_account
    contact = create_contact(account: account, metadata: { "company" => "Acme" })
    template = create_template(account: account,
      subject_template: "{{ company }} / {{ contact.company }}",
      html_body: "<p>x</p>",
      plain_body: "x")

    result = TemplateRenderer.render(template: template, contact: contact)
    assert_equal "Acme / Acme", result.subject
  end
end
