module ApiTestHelpers
  def create_account(name: "Acme", subdomain: nil)
    suffix = SecureRandom.hex(4)
    Account.create!(name: name, subdomain: subdomain || "acme-#{suffix}", plan: :free, status: :active)
  end

  def create_api_key(account:, name: "Test key")
    ApiKey.generate!(account: account, name: name)
  end
end
