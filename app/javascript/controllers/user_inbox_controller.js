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
    if (data.type !== "conversation_updated" || data.conversation_id == null || !data.preview_html) return
    const id = `conversation-preview-${String(data.conversation_id)}`
    const el = document.getElementById(id)
    if (el) el.outerHTML = data.preview_html
  }
}
