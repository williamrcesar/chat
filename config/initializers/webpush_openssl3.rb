# frozen_string_literal: true

# Monkey-patches for webpush gem to work with OpenSSL 3.0 (pkeys are immutable).
# Required for both VapidKey (JWT signing) and Encryption (payload encryption).

require "webpush"

module WebpushOpenSSL3
  # Build OpenSSL::PKey::EC from base64url-encoded VAPID public_key and private_key
  # without mutating keys (OpenSSL 3 compatible).
  # Build DER by hand to avoid Ruby ASN1 "invalid tag class" when using ASN1Data/Primitive tags.
  def self.ec_key_from_vapid_keys(public_key_b64, private_key_b64)
    priv_bin = Webpush.decode64(private_key_b64)
    pub_bin  = Webpush.decode64(public_key_b64)

    # ECPrivateKey DER (manual encoding to avoid ASN1Error):
    # SEQUENCE { version INTEGER 1, privateKey OCTET STRING, [0] OID prime256v1, [1] BIT STRING publicKey }
    oid_prime256v1 = [0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07].pack("C*")
    tag0 = "\xa0".b + [oid_prime256v1.bytesize].pack("C") + oid_prime256v1  # [0] EXPLICIT
    bit_string = "\x03".b + [pub_bin.bytesize + 1].pack("C") + "\x00".b + pub_bin  # BIT STRING (0 unused bits)
    tag1 = "\xa1".b + [bit_string.bytesize].pack("C") + bit_string  # [1] EXPLICIT BIT STRING
    priv_oct = "\x04".b + [priv_bin.bytesize].pack("C") + priv_bin  # OCTET STRING
    inner = "\x02\x01\x01".b + priv_oct + tag0 + tag1  # version 1 + privateKey + [0] + [1]
    der = "\x30".b + [inner.bytesize].pack("C") + inner
    pem = "-----BEGIN EC PRIVATE KEY-----\n" + [ der ].pack("m0").scan(/.{1,64}/).join("\n") + "\n-----END EC PRIVATE KEY-----\n"
    OpenSSL::PKey::EC.new(pem)
  end
end

# Patch VapidKey: from_keys must not call new() (which uses generate_key) nor mutate.
# We build the EC key from DER and wrap it in a minimal object that responds like VapidKey.
Webpush::VapidKey.singleton_class.prepend(Module.new do
  def from_keys(public_key, private_key)
    curve = WebpushOpenSSL3.ec_key_from_vapid_keys(public_key, private_key)
    # Return an object that has .curve and .public_key_for_push_header like VapidKey
    key = Object.new
    key.define_singleton_method(:curve) { curve }
    key.define_singleton_method(:public_key_for_push_header) do
      bin = curve.public_key.to_bn.to_s(2)
      Webpush.encode64(bin).delete("=")
    end
    key
  end
end)

# Patch Encryption: use EC.generate instead of new + generate_key (OpenSSL 3 compatible).
Webpush::Encryption.singleton_class.prepend(Module.new do
  def encrypt(message, p256dh, auth)
    assert_arguments(message, p256dh, auth)

    group_name = "prime256v1"
    salt       = Random.new.bytes(16)

    server = OpenSSL::PKey::EC.generate(group_name)
    server_public_key_bn = server.public_key.to_bn

    group              = OpenSSL::PKey::EC::Group.new(group_name)
    client_public_key_bn = OpenSSL::BN.new(Webpush.decode64(p256dh), 2)
    client_public_key   = OpenSSL::PKey::EC::Point.new(group, client_public_key_bn)

    shared_secret = server.dh_compute_key(client_public_key)

    client_auth_token = Webpush.decode64(auth)

    info                      = "WebPush: info\0#{client_public_key_bn.to_s(2)}#{server_public_key_bn.to_s(2)}"
    content_encryption_key_info = "Content-Encoding: aes128gcm\0"
    nonce_info                 = "Content-Encoding: nonce\0"

    prk = HKDF.new(shared_secret, salt: client_auth_token, algorithm: "SHA256", info: info).next_bytes(32)

    content_encryption_key = HKDF.new(prk, salt: salt, info: content_encryption_key_info).next_bytes(16)
    nonce                  = HKDF.new(prk, salt: salt, info: nonce_info).next_bytes(12)

    ciphertext = encrypt_payload(message, content_encryption_key, nonce)

    serverkey16bn = convert16bit(server_public_key_bn)
    rs = ciphertext.bytesize
    raise ArgumentError, "encrypted payload is too big" if rs > 4096

    aes128gcmheader = "#{salt}#{[rs].pack("N*")}#{[serverkey16bn.bytesize].pack("C*")}#{serverkey16bn}"

    aes128gcmheader + ciphertext
  end
end)
