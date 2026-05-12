module WebhookTestHelpers
  def create_account(name: "Acme #{SecureRandom.hex(4)}", subdomain: "acme-#{SecureRandom.hex(4)}")
    Account.create!(name: name, subdomain: subdomain)
  end

  def create_user(account: create_account, email: "user-#{SecureRandom.hex(4)}@example.com")
    User.create!(account: account, email: email, name: "Test User", password: "supersecret123")
  end

  def create_endpoint(account:, url: "https://example.com/webhooks", events: [ "contact.created" ], active: true)
    WebhookEndpoint.create!(account: account, url: url, event_types: events, active: active)
  end

  def create_contact(account:, email: "lead-#{SecureRandom.hex(4)}@example.com")
    Contact.create!(account: account, email: email)
  end

  def perform_enqueued_webhook_jobs
    enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == DeliverWebhookJob }
    ActiveJob::Base.queue_adapter.enqueued_jobs.reject! { |j| j[:job] == DeliverWebhookJob }
    enqueued.each { |j| DeliverWebhookJob.perform_now(*j[:args]) }
  end

  def with_http_client_stub(post_handler)
    original = Webhooks::HttpClient.method(:post)
    Webhooks::HttpClient.singleton_class.send(:remove_method, :post)
    Webhooks::HttpClient.define_singleton_method(:post, &post_handler)
    yield
  ensure
    Webhooks::HttpClient.singleton_class.send(:remove_method, :post)
    Webhooks::HttpClient.define_singleton_method(:post, &original)
  end
end
