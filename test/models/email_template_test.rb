require "test_helper"

class EmailTemplateTest < ActiveSupport::TestCase
  test "requires name, slug, html_body" do
    template = EmailTemplate.new(account: create_account)
    refute template.valid?
    assert_includes template.errors[:name], "can't be blank"
    assert_includes template.errors[:slug], "can't be blank"
    assert_includes template.errors[:html_body], "can't be blank"
  end

  test "enforces slug format" do
    account = create_account
    template = EmailTemplate.new(account: account, name: "X", slug: "Bad Slug!", html_body: "<p>x</p>")
    refute template.valid?
    assert_match(/lowercase alphanumeric/, template.errors[:slug].first)
  end

  test "enforces slug uniqueness per account" do
    account = create_account
    create_template(account: account, slug: "welcome")
    dup = EmailTemplate.new(account: account, name: "Welcome 2", slug: "welcome", html_body: "<p>x</p>")
    refute dup.valid?
    assert_includes dup.errors[:slug], "has already been taken"
  end

  test "allows same slug across different accounts" do
    a1 = create_account
    a2 = create_account
    create_template(account: a1, slug: "welcome")
    assert_nothing_raised do
      create_template(account: a2, slug: "welcome")
    end
  end

  test "derives plain body from html when blank" do
    account = create_account
    template = EmailTemplate.create!(
      account: account,
      name: "Welcome",
      slug: "welcome-derive",
      html_body: "<p>Hello <strong>{{ contact.first_name }}</strong>!</p><p>Goodbye.</p>",
      plain_body: ""
    )
    assert_includes template.plain_body, "Hello"
    assert_includes template.plain_body, "{{ contact.first_name }}"
    assert_includes template.plain_body, "Goodbye."
    refute_includes template.plain_body, "<p>"
  end

  test "normalizes slug from name when blank" do
    account = create_account
    template = EmailTemplate.new(account: account, name: "Cool Announcement", html_body: "<p>x</p>")
    template.valid?
    assert_equal "cool-announcement", template.slug
  end

  test "rejects malformed Liquid in subject_template" do
    account = create_account
    template = EmailTemplate.new(account: account, name: "X", slug: "x", subject_template: "{{ unterminated", html_body: "<p>ok</p>")
    refute template.valid?
    assert_match(/Liquid/, template.errors[:subject_template].first)
  end

  test "archive! and unarchive! toggle status" do
    account = create_account
    template = create_template(account: account)
    assert template.active?
    template.archive!
    assert template.archived?
    template.unarchive!
    assert template.active?
  end

  test "find_by_id_or_slug! works with both" do
    account = create_account
    template = create_template(account: account, slug: "fetchable")
    assert_equal template, EmailTemplate.find_by_id_or_slug!(account, template.id)
    assert_equal template, EmailTemplate.find_by_id_or_slug!(account, "fetchable")
  end

  test "find_by_id_or_slug! does not cross accounts" do
    a1 = create_account
    a2 = create_account
    template = create_template(account: a1, slug: "iso")
    assert_raises(ActiveRecord::RecordNotFound) do
      EmailTemplate.find_by_id_or_slug!(a2, "iso")
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      EmailTemplate.find_by_id_or_slug!(a2, template.id)
    end
  end

  test "rejects non-hash default_variables" do
    account = create_account
    template = EmailTemplate.new(account: account, name: "X", slug: "x", html_body: "<p>x</p>", default_variables: "not a hash")
    refute template.valid?
    assert_includes template.errors[:default_variables].join, "JSON object"
  end
end
