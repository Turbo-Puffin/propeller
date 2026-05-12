require "test_helper"

class Webhooks::DispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "fires on contact create with envelope and queues a delivery per endpoint" do
    account = create_account
    endpoint = create_endpoint(account: account, events: [ "contact.created" ])

    assert_difference -> { WebhookDelivery.count }, 1 do
      assert_enqueued_with(job: DeliverWebhookJob) do
        Contact.create!(account: account, email: "x@example.com")
      end
    end

    delivery = WebhookDelivery.last
    assert_equal endpoint, delivery.webhook_endpoint
    assert_equal "contact.created", delivery.event_type
    assert_equal "pending", delivery.status

    envelope = delivery.payload
    assert_equal "contact.created", envelope["event"]
    assert envelope["occurred_at"].present?
    assert_equal "x@example.com", envelope["data"]["email"]
  end

  test "does not fire to endpoints that have not subscribed" do
    account = create_account
    create_endpoint(account: account, events: [ "list.created" ])

    assert_no_difference -> { WebhookDelivery.count } do
      Contact.create!(account: account, email: "x@example.com")
    end
  end

  test "fires list.created on ContactList create" do
    account = create_account
    create_endpoint(account: account, events: [ "list.created" ])

    assert_difference -> { WebhookDelivery.count }, 1 do
      ContactList.create!(account: account, name: "VIP")
    end
    assert_equal "list.created", WebhookDelivery.last.event_type
  end

  test "fires campaign.created and campaign.scheduled appropriately" do
    account = create_account
    create_endpoint(account: account, events: [ "campaign.created", "campaign.scheduled" ])

    campaign = nil
    assert_difference -> { WebhookDelivery.where(event_type: "campaign.created").count }, 1 do
      campaign = Campaign.create!(account: account, name: "Launch")
    end

    assert_difference -> { WebhookDelivery.where(event_type: "campaign.scheduled").count }, 1 do
      campaign.update!(status: :scheduled)
    end
  end

  test "endpoint scoping does not leak across accounts" do
    account_a = create_account
    account_b = create_account
    create_endpoint(account: account_a, events: [ "contact.created" ])

    assert_no_difference -> { account_a.webhook_endpoints.first.webhook_deliveries.count } do
      Contact.create!(account: account_b, email: "leak@example.com")
    end
  end
end
