namespace :webpush do
  desc "Generate VAPID keys for Web Push. Copy the output into your .env file."
  task generate_vapid_keys: :environment do
    vapid_key = Webpush.generate_key
    puts ""
    puts "Add these to your .env file:"
    puts ""
    puts "VAPID_PUBLIC_KEY=#{vapid_key.public_key}"
    puts "VAPID_PRIVATE_KEY=#{vapid_key.private_key}"
    puts ""
  end
end
