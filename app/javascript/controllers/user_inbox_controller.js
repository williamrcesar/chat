import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Subscribes to UserChannel to update the conversation list sidebar in real time
// when a new message arrives in any conversation (unread badge + last message preview).
export default class extends Controller {
  static values = { userId: Number }

  connect() {
    if (!this.userIdValue) return
    this.subscribe()
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  subscribe() {
    const consumer = createConsumer()
    this.subscription = consumer.subscriptions.create(
      { channel: "UserChannel" },
      { received: (data) => this.handleReceived(data) }
    )
  }

  handleReceived(data) {
    if (data.type !== "conversation_updated" || data.conversation_id == null) return
    const cid = String(data.conversation_id)

    if (data.item_html) {
      // If wrapped (show.html.erb), replace inner content of wrapper
      const wrapper = document.getElementById(`conversation-item-wrapper-${cid}`)
      if (wrapper) {
        // Preserve the active-highlight class on the wrapper
        const wasActive = wrapper.classList.contains("bg-[#2a3942]")
        wrapper.innerHTML = data.item_html
        if (wasActive) wrapper.classList.add("bg-[#2a3942]")
        return
      }
      // Direct item (index.html.erb) — replace the item itself
      const item = document.getElementById(`conversation-item-${cid}`)
      if (item) { item.outerHTML = data.item_html; return }
    }

    // Fallback: replace only the preview section (timestamp stays stale)
    if (data.preview_html) {
      const preview = document.getElementById(`conversation-preview-${cid}`)
      if (preview) preview.outerHTML = data.preview_html
    }
  }
}
