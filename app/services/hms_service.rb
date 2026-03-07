# 100ms.live: room creation and JWT auth token generation.
# Requires HMS_APP_ACCESS_KEY, HMS_APP_SECRET, HMS_TEMPLATE_ID in ENV.
class HmsService
  API_BASE = "https://api.100ms.live/v2"

  class Error < StandardError; end

  def self.create_room(name:, template_id: nil)
    template_id ||= ENV["HMS_TEMPLATE_ID"]
    raise Error, "HMS_TEMPLATE_ID is required" if template_id.blank?

    token = generate_management_token
    uri = URI("#{API_BASE}/rooms")
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{token}"
    req["Content-Type"] = "application/json"
    req.body = {
      name: name.to_s,
      template_id: template_id
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(req) }
    unless res.is_a?(Net::HTTPSuccess)
      raise Error, "100ms create room failed: #{res.code} #{res.body}"
    end

    data = JSON.parse(res.body)
    data["id"]
  end

  def self.generate_auth_token(room_id:, user_id:, role: "host")
    now = Time.now.to_i
    exp = now + 24 * 3600
    payload = {
      access_key: ENV["HMS_APP_ACCESS_KEY"],
      type: "app",
      version: 2,
      room_id: room_id,
      user_id: user_id.to_s,
      role: role,
      jti: SecureRandom.uuid,
      iat: now,
      nbf: now,
      exp: exp
    }
    JWT.encode(payload, ENV["HMS_APP_SECRET"], "HS256")
  end

  def self.generate_management_token
    now = Time.now.to_i
    exp = now + 86400
    payload = {
      access_key: ENV["HMS_APP_ACCESS_KEY"],
      type: "management",
      version: 2,
      jti: SecureRandom.uuid,
      iat: now,
      nbf: now,
      exp: exp
    }
    JWT.encode(payload, ENV["HMS_APP_SECRET"], "HS256")
  end
end
