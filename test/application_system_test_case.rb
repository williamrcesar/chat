require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Start each test with a fresh browser. Capybara 3.40's CDP reset uses an
  # origin wildcard rejected by newer Chrome versions.
  setup do
    page.driver.define_singleton_method(:reset!) { quit }
  end

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--window-size=1400,1400")
    options.add_argument("--use-fake-device-for-media-stream")
    options.add_argument("--use-fake-ui-for-media-stream")
    options.add_argument("--no-sandbox") if ENV["CHROME_NO_SANDBOX"] == "1"
  end
end
