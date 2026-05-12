require "test_helper"

class Webhooks::SignerTest < ActiveSupport::TestCase
  test "produces a stable sha256= prefixed hex digest" do
    sig = Webhooks::Signer.sign("hello", "secret")
    assert sig.start_with?("sha256=")
    expected = OpenSSL::HMAC.hexdigest("SHA256", "secret", "hello")
    assert_equal "sha256=#{expected}", sig
  end

  test "verify accepts the matching signature" do
    body = '{"event":"contact.created"}'
    secret = "whsec_abc"
    sig = Webhooks::Signer.sign(body, secret)
    assert Webhooks::Signer.verify(body, secret, sig)
  end

  test "verify rejects a tampered body" do
    secret = "whsec_abc"
    sig = Webhooks::Signer.sign("original", secret)
    refute Webhooks::Signer.verify("tampered", secret, sig)
  end

  test "verify rejects the wrong secret" do
    sig = Webhooks::Signer.sign("body", "right")
    refute Webhooks::Signer.verify("body", "wrong", sig)
  end
end
