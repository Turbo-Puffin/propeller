require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  setup do
    @account = create_account
  end

  test "generate! creates a key with a pk_live_ prefix by default" do
    key = ApiKey.generate!(account: @account, name: "Prod")

    assert key.persisted?
    assert key.plaintext_key.start_with?("pk_live_")
    assert_equal 16, key.key_prefix.length
    assert key.key_prefix.start_with?("pk_live_")
    assert_equal Digest::SHA256.hexdigest(key.plaintext_key), key.key_digest
  end

  test "generate! supports test environment prefix" do
    key = ApiKey.generate!(account: @account, name: "Sandbox", environment: "test")

    assert key.plaintext_key.start_with?("pk_test_")
    assert key.key_prefix.start_with?("pk_test_")
  end

  test "generate! raises for unknown environment" do
    assert_raises(ArgumentError) do
      ApiKey.generate!(account: @account, name: "Bad", environment: "staging")
    end
  end

  test "authenticate returns the key for a valid token via secure_compare" do
    key = ApiKey.generate!(account: @account, name: "Prod")

    assert_equal key, ApiKey.authenticate(key.plaintext_key)
  end

  test "authenticate returns nil for unknown token" do
    ApiKey.generate!(account: @account, name: "Prod")

    assert_nil ApiKey.authenticate("pk_live_doesnotexistxxxxx")
    assert_nil ApiKey.authenticate(nil)
    assert_nil ApiKey.authenticate("")
  end

  test "authenticate returns nil for revoked keys" do
    key = ApiKey.generate!(account: @account, name: "Prod")
    key.revoke!

    assert_nil ApiKey.authenticate(key.plaintext_key)
  end

  test "authenticate rejects a token whose digest does not match (timing-safe comparison)" do
    key = ApiKey.generate!(account: @account, name: "Prod")
    fake = key.plaintext_key.sub(/.$/, "0")

    assert_nil ApiKey.authenticate(fake)
  end

  test "touch_last_used! is rate-limited to ~1 minute" do
    key = ApiKey.generate!(account: @account, name: "Prod")
    assert_nil key.last_used_at

    key.touch_last_used!
    first = key.reload.last_used_at
    assert_not_nil first

    key.touch_last_used!
    assert_equal first.to_i, key.reload.last_used_at.to_i

    key.update_column(:last_used_at, 2.minutes.ago)
    key.touch_last_used!
    assert key.reload.last_used_at > 30.seconds.ago
  end

  test "revoke! sets revoked_at and revoked? returns true" do
    key = ApiKey.generate!(account: @account, name: "Prod")
    refute key.revoked?
    key.revoke!
    assert key.revoked?
  end

  test "key_digest is unique across keys" do
    key1 = ApiKey.generate!(account: @account, name: "One")
    duplicate = ApiKey.new(account: @account, name: "Dup", key_prefix: key1.key_prefix, key_digest: key1.key_digest)

    refute duplicate.valid?
    assert_includes duplicate.errors[:key_digest], "has already been taken"
  end
end
