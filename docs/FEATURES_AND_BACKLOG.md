# Current Features and Backlog

Updated during the pre-engine validation work on 2026-11-18. Source code presence is distinct from browser/provider validation; see VALIDATION.md for executed checks and limitations.

## Priority features already present

| Feature | Current implementation | Remaining validation |
| --- | --- | --- |
| Voice messages | Browser MediaRecorder, pause/cancel, review, upload, waveform player and playback speeds from 1x to 3.5x | Real microphone and codec behavior across browsers; 0.25x–4x is not implemented |
| Voice/video calls | 100ms rooms/tokens, Action Cable offers, accept/reject/end and screen sharing | Two real clients with valid 100ms credentials |
| Stickers | Personal library, upload, crop/edit, send, save from chat and optional GIPHY search; upload/crop/send tested in Chrome | Animated content, other browsers and GIPHY with a configured key |
| Composer emojis | Picker, favorites, insertion at cursor and Unicode text messages | Mobile keyboard and browser interaction |
| Reactions | Per-message emoji reactions and broadcasts | Multi-client browser behavior |
| Link previews | Background metadata fetch, relative cover URL resolution and URL-only fallback card | External-site variability and worker deployment |
| Notification sound | Service worker message listener exists in app/javascript/application.js | Autoplay restrictions and OS/browser behavior; closed tabs cannot guarantee custom sound |

Voice upload failures retain the recording for retry. Link preview fetching validates public network destinations, pins the selected IP, rechecks redirects, limits redirect depth and bounds response size. Preview network failures must not prevent sending the original message.

## Other existing modules

Direct and group conversations; Markdown; image/audio/video/document attachments; reply and forwarding; soft deletion for everyone; sent/delivered/read states; unread counts; archive/pin; full-text PostgreSQL search; infinite scroll; presence and typing; profiles; nickname contact requests; simple message templates; JWT REST API; Web Push/PWA; administration; company attendants/departments/routing; marketing templates/campaigns/interactive buttons and lists/Kanban.

Existing modules still require broader regression coverage. A contact request can be blocked, but comprehensive user blocking should not be inferred from that alone.

## Product TODO

- [ ] End-to-end encryption, with a design compatible with search, attachments and multi-device access.
- [ ] FCM/APNs mobile push; mobile clients remain separate projects.
- [ ] Disappearing messages and stories/status.
- [ ] Comprehensive user blocking across messages, contacts and calls.
- [ ] Rate limiting and external webhooks.
- [ ] Two-factor authentication and light/dark theme toggle.
- [ ] Group mentions.
- [ ] AI attendant integration, SLA alerts and company analytics/CSAT.
- [ ] Sticker packs and pack import/export (the existing personal sticker library is not a pack system).
- [ ] Additional audio speeds, if the intended range is 0.25x–4x.

## Engineering TODO before engine extraction

- [ ] Migrate Ruby 3.2 / Rails 7.2 to supported versions and rerun the regression suite (Brakeman lifecycle warnings).
- [ ] Characterize all company, marketing, API, admin and push flows with regression tests.
- [ ] Make direct-conversation creation unique under concurrent requests.
- [ ] Persist campaign daily budgets and resumable/idempotent delivery instead of a per-job counter.
- [ ] Decouple identity/authentication, optional modules, jobs, routes and assets from application globals.
- [ ] Validate optional-provider credentials and failure behavior without requiring those providers for core chat.
