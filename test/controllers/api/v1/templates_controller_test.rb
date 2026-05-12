require "test_helper"

class Api::V1::TemplatesControllerTest < ActionDispatch::IntegrationTest
  test "requires auth" do
    get api_v1_templates_url
    assert_response :unauthorized
  end

  test "create + show + update + index round-trip" do
    account = create_account
    user = create_user(account: account)
    login_as(user)

    post api_v1_templates_url,
         params: { name: "Welcome", slug: "welcome", subject_template: "Hi {{ contact.first_name }}", html_body: "<p>Hi</p>" },
         as: :json
    assert_response :created
    body = response.parsed_body
    assert_equal "welcome", body["slug"]
    assert body["plain_body"].present?, "plain_body should be auto-derived"
    id = body["id"]

    get api_v1_template_url(id), as: :json
    assert_response :success
    assert_equal "Welcome", response.parsed_body["name"]

    # find by slug too
    get api_v1_template_url("welcome"), as: :json
    assert_response :success

    patch api_v1_template_url(id), params: { name: "Welcome v2" }, as: :json
    assert_response :success
    assert_equal "Welcome v2", response.parsed_body["name"]

    get api_v1_templates_url, as: :json
    assert_response :success
    assert_equal 1, response.parsed_body.length
  end

  test "create returns 422 on invalid Liquid" do
    account = create_account
    user = create_user(account: account)
    login_as(user)

    post api_v1_templates_url,
         params: { name: "Bad", slug: "bad", subject_template: "{{ unterminated", html_body: "<p>x</p>" },
         as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid", response.parsed_body["error"]
  end

  test "preview renders with sample contact when no contact_id provided" do
    account = create_account
    user = create_user(account: account)
    login_as(user)
    template = create_template(account: account,
      subject_template: "Hi {{ contact.first_name }}",
      html_body: "<p>{{ contact.first_name }} {{ contact.last_name }}</p>",
      plain_body: "")

    post preview_api_v1_template_url(template), as: :json
    assert_response :success
    assert_equal "Hi Sample", response.parsed_body["subject"]
    assert_match(/Sample Contact/, response.parsed_body["html"])
  end

  test "preview renders with provided contact" do
    account = create_account
    user = create_user(account: account)
    contact = create_contact(account: account, first_name: "Grace", last_name: "Hopper")
    login_as(user)
    template = create_template(account: account,
      subject_template: "Hi {{ contact.first_name }}",
      html_body: "<p>{{ contact.first_name }} {{ contact.last_name }}</p>",
      plain_body: "{{ contact.first_name }}")

    post preview_api_v1_template_url(template), params: { contact_id: contact.id }, as: :json
    assert_response :success
    assert_equal "Hi Grace", response.parsed_body["subject"]
    assert_match(/Grace Hopper/, response.parsed_body["html"])
  end

  test "destroy without hard archives the template" do
    account = create_account
    user = create_user(account: account)
    login_as(user)
    template = create_template(account: account)

    delete api_v1_template_url(template), as: :json
    assert_response :success
    assert_equal "archived", template.reload.status
  end

  test "destroy with hard=true permanently removes" do
    account = create_account
    user = create_user(account: account)
    login_as(user)
    template = create_template(account: account)

    delete api_v1_template_url(template), params: { hard: "true" }, as: :json
    assert_response :no_content
    assert_nil EmailTemplate.find_by(id: template.id)
  end

  test "cross-account isolation: cannot read another account's template" do
    a1 = create_account
    a2 = create_account
    user2 = create_user(account: a2)
    template = create_template(account: a1, slug: "secret")

    login_as(user2)
    get api_v1_template_url(template.id), as: :json
    assert_response :not_found

    get api_v1_template_url("secret"), as: :json
    assert_response :not_found
  end

  test "index supports status filter" do
    account = create_account
    user = create_user(account: account)
    login_as(user)
    create_template(account: account, slug: "active-1", status: "active")
    create_template(account: account, slug: "archived-1", status: "archived")

    get api_v1_templates_url(status: "archived"), as: :json
    assert_response :success
    assert_equal 1, response.parsed_body.length
    assert_equal "archived", response.parsed_body.first["status"]
  end
end
