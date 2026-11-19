require "test_helper"
require "minitest/mock"

class LinkPreviewFetcherTest < ActiveSupport::TestCase
  class FakeFetcher < LinkPreviewFetcher
    attr_accessor :addresses, :responses
    attr_reader :requests

    def initialize
      @addresses = [ "93.184.216.34" ]
      @responses = []
      @requests = []
    end

    private

    def resolve_addresses(hostname)
      hostname == "private.example" ? [ "127.0.0.1" ] : addresses
    end

    def request(uri, address)
      @requests << [ uri, address ]
      responses.shift
    end
  end

  setup { @fetcher = FakeFetcher.new }

  test "rejects non-http schemes credentials and alternate ports before connecting" do
    %w[file:///etc/passwd ftp://example.com https://user:pass@example.com https://example.com:3000].each do |url|
      assert_nil @fetcher.fetch(url)
    end
    assert_empty @fetcher.requests
  end

  test "rejects private reserved mapped and mixed DNS results" do
    %w[127.0.0.1 10.0.0.1 169.254.169.254 172.16.0.1 192.168.1.1 100.64.0.1 ::1 fc00::1 fe80::1 ::ffff:127.0.0.1 2002:7f00:1::].each do |address|
      @fetcher.addresses = [ address ]
      assert_nil @fetcher.fetch("https://example.com"), address
    end
    @fetcher.addresses = [ "93.184.216.34", "127.0.0.1" ]
    assert_nil @fetcher.fetch("https://example.com")
    assert_empty @fetcher.requests
  end

  test "returns public HTML using the validated address" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response["content-type"] = "text/html; charset=utf-8"
    @fetcher.responses = [ [ response, "<title>Example</title>" ] ]
    assert_equal "<title>Example</title>", @fetcher.fetch("https://example.com")
    assert_equal "93.184.216.34", @fetcher.requests.first.last
  end

  test "revalidates redirects before connecting to their destination" do
    response = Net::HTTPFound.new("1.1", "302", "Found")
    response["location"] = "http://private.example/secret"
    @fetcher.responses = [ [ response, "" ] ]
    assert_nil @fetcher.fetch("https://example.com")
    assert_equal 1, @fetcher.requests.size
  end

  test "does not parse non HTML responses" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response["content-type"] = "image/png"
    @fetcher.responses = [ [ response, "image bytes" ] ]
    assert_nil @fetcher.fetch("https://example.com")
  end

  test "stops redirect loops" do
    response = Net::HTTPFound.new("1.1", "302", "Found")
    response["location"] = "/loop"
    @fetcher.responses = Array.new(4) { [ response, "" ] }
    assert_nil @fetcher.fetch("https://example.com")
    assert_equal 4, @fetcher.requests.size
  end

  test "bounds streamed responses and pins the vetted IP on the transport" do
    fetcher = LinkPreviewFetcher.new
    fetcher.define_singleton_method(:resolve_addresses) { |_| [ "93.184.216.34" ] }
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response["content-type"] = "text/html"
    response.define_singleton_method(:read_body) { |&block| block.call("x" * (LinkPreviewFetcher::MAX_BYTES + 1)) }
    transport = Struct.new(:ipaddr, :use_ssl, :open_timeout, :read_timeout, :write_timeout, :max_retries).new
    transport.define_singleton_method(:start) { |&block| block.call(self) }
    transport.define_singleton_method(:request) { |_, &block| block.call(response) }

    Net::HTTP.stub(:new, transport) do
      assert_nil fetcher.fetch("https://example.com")
    end
    assert_equal "93.184.216.34", transport.ipaddr
    assert transport.use_ssl
  end

  test "network timeouts fail without losing the original message" do
    @fetcher.define_singleton_method(:request) { |_, _| raise Net::ReadTimeout }
    assert_nil @fetcher.fetch("https://example.com")
  end
end
