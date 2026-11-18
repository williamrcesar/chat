# Pre-engine validation — 2026-11-18

This work validates and fixes the existing application before revisiting the Rails engine plan. It does not claim complete product coverage.

## Changes

- Voice uploads retain their recording on failure and reject duplicate in-flight send clicks. Microphone streams granted after navigation are stopped; releasing the button while permission is pending transitions to locked recording when ready.
- Sticker cropping imports Cropper as a module. The crop editor fits short viewports without clipping its save/send controls.
- Sticker sends invoke the message policy explicitly. Forwarded attachments are attached before validation/persistence, including audio without text.
- Message sequence allocation locks the conversation row within the insert transaction; concurrent-send coverage exercises PostgreSQL locking.
- Link previews use public-address validation, pinned DNS results, redirect revalidation, redirect/response-size limits and network timeouts. The original message survives a failed preview fetch.
- Global user administration requires a global administrator. Company supervisors cannot promote themselves or edit global users; role changes use the dedicated admin action.
- Missing 100ms signing credentials raise a controlled provider error.
- Tests use the Active Job test adapter, compatible Minitest 5, transactional cleanup and fresh Chrome sessions. Executable scripts preserve LF on Windows checkouts. CI runs the JavaScript regressions and uses an explicit test database.

## Verification

Environment: Ubuntu 24.04 under WSL, Ruby 3.2.3, Rails 7.2.3, isolated PostgreSQL 17 database, Chrome/ChromeDriver 158. Browser audio capture uses Chrome's simulated media device.

- Server suite: **33 tests, 88 assertions, no failures/errors/skips**.
- JavaScript behavior: **5 tests passed** (Unicode emoji insertion; upload success/failure; duplicate clicks; late microphone permission).
- JavaScript syntax: all Stimulus controller files checked successfully with Node.
- Browser suite: **4 tests, 13 assertions, no failures/errors/skips**. Covered picker-to-message emoji sending, microphone recording/review/upload, sticker upload/crop/send in a short viewport, and preview-card rendering.
- RuboCop: **154 Ruby files, no offenses**.
- Asset compilation: passed, including Tailwind and Sprockets.
- Importmap audit: **no vulnerable packages found** by that audit.
- Brakeman: **no scan errors; two lifecycle warnings remain**. The mass-assignment warning was resolved by removing role from generic user updates and restricting global user administration.

Typical verification commands, after configuring an isolated PostgreSQL test database and test-only secrets:

```sh
bundle install
RAILS_ENV=test bin/rails db:test:prepare test test:system
node --test test/javascript/*.mjs
bundle exec rubocop
RAILS_ENV=test bin/rails assets:precompile
bin/importmap audit
bin/brakeman --no-pager
```

Set `CHROME_BIN` if Chrome is not on PATH. The test configuration supplies fake media-device flags; these do not apply to production browsers. Never point these test commands at a development or production database.

## Remaining limits and follow-up

- Brakeman reports Ruby 3.2 and Rails 7.2 as past their maintenance windows. Upgrade to supported Ruby/Rails versions in a separately validated migration before adopting this baseline for a new gem release. This patch preserves the application's current runtime rather than silently making a major-version upgrade.
- Real voice/video calls and screen sharing require configured 100ms credentials and two clients; only permission/missing-configuration paths are covered here. No external call was placed.
- GIPHY search needs its own key. Browser microphone permission/codec behavior on real devices, custom notification sound, VAPID push and storage-provider delivery still need provider/device validation.
- Company, marketing, admin, API and push modules are not exhaustively covered by the current suite. Known campaign resumption/daily-budget and direct-conversation uniqueness work remains in FEATURES_AND_BACKLOG.md.
- No engine implementation or production deployment is part of this change.
