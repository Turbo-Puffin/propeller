module Webhooks
  # HMAC-SHA256 of the raw payload body, encoded as hex. Matches the
  # Stripe / GitHub style: header value is "sha256=<hex>".
  module Signer
    module_function

    def sign(payload_body, secret)
      digest = OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, payload_body.to_s)
      "sha256=#{digest}"
    end

    def verify(payload_body, secret, signature_header)
      expected = sign(payload_body, secret)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature_header.to_s)
    end
  end
end
