import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Subscribes to ContactRequestsChannel and updates the sidebar badge in real-time.
export default class extends Controller {
  static targets = ["badge"]

  connect() {
    const userId = document.body.dataset.currentUserId
    if (!userId) return

    this._consumer = createConsumer()
    this._subscription = this._consumer.subscriptions.create(
      { channel: "ContactRequestsChannel" },
      { received: (data) => this._handleData(data) }
    )
  }

  disconnect() {
    this._subscription?.unsubscribe()
    this._consumer?.disconnect()
  }

  _handleData(data) {
    if (data.type !== "new_request") return

    // Update badge count
    const badge = document.getElementById("contact-requests-badge")
    if (badge) {
      const current = parseInt(badge.textContent) || 0
      badge.textContent = current + 1
      badge.classList.remove("hidden")
    } else {
      // Badge doesn't exist yet — create it
      const link = document.querySelector("a[href*='contact_requests']")
      if (link && !link.querySelector("#contact-requests-badge")) {
        link.style.position = "relative"
        const span = document.createElement("span")
        span.id = "contact-requests-badge"
        span.className = "absolute -top-1 -right-1 bg-[#00a884] text-white text-xs font-bold rounded-full w-4 h-4 flex items-center justify-center"
        span.textContent = "1"
        link.appendChild(span)
      }
    }

    // Show a toast notification
    this._showToast(data.sender_name, data.preview)
  }

  _showToast(senderName, preview) {
    const toast = document.createElement("div")
    toast.className = "fixed bottom-6 right-6 z-50 bg-[#202c33] border border-[#2a3942] text-white px-4 py-3 rounded-xl shadow-2xl max-w-sm flex items-start gap-3 animate-slide-in"
    toast.innerHTML = `
      <div class="w-8 h-8 rounded-full bg-[#00a884] flex items-center justify-center text-white font-bold text-sm flex-shrink-0">
        ${(senderName || "?")[0].toUpperCase()}
      </div>
      <div class="flex-1 min-w-0">
        <p class="font-semibold text-sm">${senderName}</p>
        <p class="text-[#8696a0] text-xs truncate">${preview || "Quer conversar com você"}</p>
        <a href="/contact_requests" class="text-[#00a884] text-xs font-semibold mt-1 block">Ver solicitação →</a>
      </div>
      <button onclick="this.parentElement.remove()" class="text-[#8696a0] hover:text-white ml-2">✕</button>`
    document.body.appendChild(toast)
    setTimeout(() => toast.remove(), 8000)
  }
}
