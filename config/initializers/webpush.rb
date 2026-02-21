# Web Push / VAPID configuration
# Generate keys once with:
#   rails webpush:generate_vapid_keys   (see lib/tasks/webpush.rake)
# Then copy the output into your .env file.

VAPID_PUBLIC_KEY  = ENV.fetch("VAPID_PUBLIC_KEY",  nil)
VAPID_PRIVATE_KEY = ENV.fetch("VAPID_PRIVATE_KEY", nil)
VAPID_SUBJECT     = ENV.fetch("VAPID_SUBJECT",     "mailto:admin@chat.app")
