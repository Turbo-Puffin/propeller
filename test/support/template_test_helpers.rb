module TemplateTestHelpers
  def create_account(name: "Acme #{SecureRandom.hex(4)}", subdomain: "acme-#{SecureRandom.hex(4)}")
    Account.create!(name: name, subdomain: subdomain)
  end

  def create_user(account: create_account, email: "user-#{SecureRandom.hex(4)}@example.com")
    User.create!(account: account, email: email, name: "Test User", password: "supersecret123")
  end

  def create_contact(account:, email: "lead-#{SecureRandom.hex(4)}@example.com", first_name: "Ada", last_name: "Lovelace", metadata: {})
    Contact.create!(account: account, email: email, first_name: first_name, last_name: last_name, metadata: metadata)
  end

  def create_template(account:, **attrs)
    defaults = {
      name: "Welcome",
      slug: "welcome-#{SecureRandom.hex(3)}",
      subject_template: "Hi {{ contact.first_name }}",
      html_body: "<p>Hello {{ contact.first_name }}!</p>",
      plain_body: "Hello {{ contact.first_name }}!",
      default_variables: {},
      status: "active"
    }
    EmailTemplate.create!(defaults.merge(account: account, **attrs))
  end

  def login_as(user)
    post login_path, params: { email: user.email, password: "supersecret123" }
  end
end
