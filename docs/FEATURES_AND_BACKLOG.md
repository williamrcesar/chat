# Current Features and Backlog

Summary of what the Chat app already provides and what is left to implement (focus on notifications, emojis/stickers, and audio).

---

## What Already Exists

### Messaging and chat
- Direct (1:1) and group conversations
- Real-time messages (ActionCable + Turbo Streams)
- Text with Markdown
- Attachments: **image, audio, video, and document** (upload, display, and message type)
- Audio message: send audio file and `<audio controls>` player in the bubble (no in-app voice recording, no playback speed control)
- Reply to message
- Forward message
- Delete for everyone (soft delete with broadcast)
- Link preview (metadata)
- Message templates with `{{name}}` variables
- Full-text message search (pg_search)

### Reactions and emojis
- **Message reactions** (emoji picker on hover): 👍 ❤️ 😂 😮 😢 🙏 — only as reaction, not emoji as message content
- Not implemented: sending emoji as a message or **stickers**

### Web notifications (push)
- Web Push (VAPID): user can enable "Notifications" and the server sends push to all subscribed devices
- Payload already includes:
  - **Title:** sender name
  - **Body:** message text snippet (up to 120 chars) or "sent you an image/audio/video/document" (+ text if any)
  - **Sound:** URL (per-participant or default)
  - **Icon:** participant avatar/color
  - **Click:** opens conversation (`/conversations/:id`)
- Service worker shows the notification and sends `postMessage` with `play-notification-sound` to open tabs
- **Limitation:** there is no front-end listener for `play-notification-sound`, so **custom sound may not play** in practice (browser-dependent; often only system default or none)

### Calls (100ms)
- Voice and video call buttons in the conversation
- Call notifications: push "So-and-so is calling (video/voice)", "Call answered", "Call not answered"
- Screen sharing (button during active call)

### Other
- Typing indicator, online / last seen
- Message status: ✓ (sent), ✓✓ (delivered), ✓✓ blue (read)
- Unread badge, archive and pin conversations
- Profile with avatar
- Contact system by @nickname (friend request, accept/block)
- Marketing: templates, bulk campaigns, delivery Kanban, interactive messages (button/list)
- Company: attendants, departments, assignment queue, real-time dashboard
- REST API v1 with JWT

---

## What's Missing (backlog)

### 1. Web notifications with sound and some text
- **Text:** already implemented (body with message snippet or "sent image/audio/…").
- **Sound:**
  - Keep `sound` in the payload (already in `MessageBroadcastJob`).
  - Add a **listener** in the front end for the service worker's `play-notification-sound` `postMessage` and play the audio (e.g. `<audio>` with `payload.sound` URL) when the tab is open.
  - When the tab is closed, behavior is OS/browser-dependent; document this for users.
- **Optional:** "Notification sound" preference (on/off) and sound choice (partially exists via `notification_sound_file` / `effective_notification_sound`).

### 2. Send emojis and stickers
- **Emojis:**
  - Allow choosing and sending emojis as **message content** (e.g. picker next to the text field, or shortcut like `:smile:`), not only as reactions.
- **Stickers:**
  - Send stickers as a message type (e.g. small/square image with transparent background, shown as a "sticker" in the bubble).
  - Not implemented: no sticker model or UI to send.

### 3. Stickers: create in-app or add existing (e.g. WhatsApp-style)
- **Option A – Create in the system:**
  - Model (e.g. `StickerPack`, `Sticker`) with image (Active Storage), order, pack.
  - CRUD (admin or user) to create packs and stickers.
  - Chat UI: open pack gallery, pick sticker, send as message (type `sticker`).
- **Option B – Use "WhatsApp-style" stickers:**
  - Licensing: official WhatsApp packs cannot be redistributed.
  - Alternative: use free packs (e.g. Telegram-compatible sticker packs, or your own/user-created packs).
- **Recommendation:** implement **Option A** (own packs and stickers); later, optionally allow importing/mapping images in "WhatsApp-style" format (square, PNG with transparency).

### 4. Audio: voice message (WhatsApp-style) + playback speed (0.25x to 4x)
- **In-app voice recording:**
  - Microphone button in the conversation input.
  - Record in the browser (MediaRecorder / getUserMedia), send as file (e.g. `audio/ogg` or `audio/webm`), create message with `message_type: audio` and attachment (already supported by the model).
  - Player in bubble: keep `<audio controls>` and **add speed control**.
- **Playback speed:**
  - Use `<audio>` `playbackRate`: e.g. 0.25, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4 (or steps like 0.5x, 1x, 1.5x, 2x, 4x).
  - UI: "speed" button or menu next to the player (1x → 1.5x → 2x → 0.5x …) or slider.
- **Note:** "-4" can be read as "up to 4x" (min 0.25x, max 4x); there is no real "negative" playback speed, only slower/faster.

---

## Summary table

| Feature | Status | Notes |
|--------|--------|--------|
| Web notification with text | ✅ | Body with snippet or "sent image/audio/…" |
| Web notification with sound | ⚠️ Partial | Payload has `sound`; missing in-tab playback (listener for `play-notification-sound`) |
| Send emoji as message | ❌ | Only reactions today; need picker in composer |
| Send stickers | ❌ | No model or UI |
| Stickers: create in app | ❌ | Backlog (packs + stickers + chat gallery) |
| Stickers: WhatsApp-style | ❌ | Use only free or own packs (licensing) |
| Audio: send file | ✅ | Already supported (audio attachment) |
| Audio: record voice in app | ❌ | Need browser recording + send |
| Audio: speed 0.25x–4x | ❌ | Need `playbackRate` control on player |

---

*Document for tracking current features and backlog. Update as features are implemented.*
