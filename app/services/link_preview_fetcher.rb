require "net/http"
require "resolv"
require "ipaddr"

# Resolve before connecting and pin the vetted address to prevent DNS rebinding.
class LinkPreviewFetcher
  class UnsafeUrl < StandardError; end

  MAX_BYTES = 1.megabyte
  MAX_REDIRECTS = 3
  BLOCKED_NETWORKS = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
    172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16
    198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    2001::/23 2001:db8::/32 2002::/16
  ].map { |range| IPAddr.new(range) }.freeze
  PUBLIC_IPV6 = IPAddr.new("2000::/3")

  def fetch(url, redirects: MAX_REDIRECTS)
    uri = URI.parse(url)
    raise UnsafeUrl unless uri.is_a?(URI::HTTP) && uri.host.present?
    raise UnsafeUrl if uri.userinfo || ![ 80, 443 ].include?(uri.port)

    addresses = resolve_addresses(uri.hostname)
    raise UnsafeUrl if addresses.empty? || addresses.any? { |address| !public_address?(address) }

    response, body = request(uri, addresses.first)
    if response.is_a?(Net::HTTPRedirection)
      raise UnsafeUrl if redirects.zero? || response["location"].blank?
      return fetch(URI.join(uri.to_s, response["location"]).to_s, redirects: redirects - 1)
    end
    return unless response.is_a?(Net::HTTPSuccess)
    return unless response["content-type"].to_s.match?(%r{\A(?:text/html|application/xhtml\+xml)(?:;|\z)}i)

    body.force_encoding("UTF-8").scrub
  rescue UnsafeUrl, URI::InvalidURIError, Resolv::ResolvError, SocketError,
         Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError
    nil
  end

  private

  def resolve_addresses(hostname)
    Resolv.getaddresses(hostname)
  end

  def public_address?(address)
    ip = IPAddr.new(address)
    return false if ip.ipv6? && !PUBLIC_IPV6.include?(ip)
    BLOCKED_NETWORKS.none? { |network| network.include?(ip) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def request(uri, address)
    # Disable environment proxies so the checked destination is the connected one.
    http = Net::HTTP.new(uri.hostname, uri.port, nil)
    http.ipaddr = address
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5
    http.write_timeout = 5
    http.max_retries = 0
    body = +""
    response = nil
    Timeout.timeout(10) do
      http.start do |connection|
        connection.request(Net::HTTP::Get.new(uri.request_uri, "User-Agent" => "ChatLinkPreview/1.0")) do |result|
          response = result
          result.read_body do |chunk|
            raise UnsafeUrl if body.bytesize + chunk.bytesize > MAX_BYTES
            body << chunk
          end
        end
      end
    end
    [ response, body ]
  end
end
