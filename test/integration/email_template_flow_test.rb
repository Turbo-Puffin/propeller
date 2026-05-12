require "test_helper"

class EmailTemplateFlowTest < ActionDispatch::IntegrationTest
  test "create via API, preview via API, returns rendered subject + html + plain" do
    account = create_account
    user = create_user(account: account)
    contact = create_contact(account: account, first_name: "Ada", last_name: "Lovelace")
    login_as(user)

    post api_v1_templates_url,
         params: {
           name: "Launch Day",
           slug: "launch-day",
           subject_template: "{{ contact.first_name }}, we launched!",
           html_body: "<p>Hey {{ contact.first_name }} {{ contact.last_name }}, check it out: {{ promo }}.</p>",
           plain_body: "Hey {{ contact.first_name }}, check it out: {{ promo }}.",
           default_variables: { "promo" => "https://propeller.rocks" }
         },
         as: :json
    assert_response :created
    template_id = response.parsed_body["id"]

    post preview_api_v1_template_url(template_id), params: { contact_id: contact.id }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "Ada, we launched!", body["subject"]
    assert_match(/Hey Ada Lovelace/, body["html"])
    assert_match(/propeller\.rocks/, body["html"])
    assert_match(/Hey Ada/, body["plain"])
  end
end
