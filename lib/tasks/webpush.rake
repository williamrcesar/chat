namespace :webpush do
  desc "Generate VAPID keys for Web Push. Copy the output into your .env file."
  task generate_vapid_keys: :environment do
    # OpenSSL 3.0+: keys are immutable; generate in one step instead of Webpush.generate_key
    curve = OpenSSL::PKey::EC.generate("prime256v1")
    pub_binary  = curve.public_key.to_bn.to_s(2)
    priv_binary = curve.private_key.to_s(2)
    public_key  = Base64.urlsafe_encode64(pub_binary)
    private_key = Base64.urlsafe_encode64(priv_binary)

    puts ""
    puts "Add these to your .env file:"
    puts ""
    puts "VAPID_PUBLIC_KEY=#{public_key}"
    puts "VAPID_PRIVATE_KEY=#{private_key}"
    puts ""
  end

  task generate_vapid: :generate_vapid_keys
end
