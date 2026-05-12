module Webhooks
  # Thin Net::HTTP wrapper so the job stays testable. Returns a Net::HTTPResponse.
  module HttpClient
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    module_function

    def post(url, body, headers)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = body
      http.request(request)
    end
  end
end
