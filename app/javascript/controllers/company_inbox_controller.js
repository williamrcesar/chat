import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

// Manages the live company dashboard inbox.
// Subscribes to CompanyChannel and updates attendant status cards and
// assignment Kanban columns in real time.
export default class extends Controller {
  static targets = [
    "attendantBoard", "attendantCard",
    "column", "cards", "count", "card"
  ]
  static values = { companyId: Number }

  connect() {
    this._subscribe()
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  // Called by the status dropdown for the current user's attendant card
  updateMyStatus(e) {
    const status      = e.target.value
    const attendantId = e.target.dataset.attendantId

    this.subscription?.perform("update_status", { status })
  }

  // ── ActionCable handler ──────────────────────────────────────────────────

  _subscribe() {
    const companyId = this.companyIdValue
    this.subscription = consumer.subscriptions.create(
      { channel: "CompanyChannel", company_id: companyId },
      { received: (data) => this._handleReceived(data) }
    )
  }

  _handleReceived(data) {
    switch (data.type) {
      case "attendant_status":
        this._updateAttendantCard(data)
        break
      case "assignment_update":
        this._updateAssignmentCard(data)
        break
      case "new_queued_assignment":
        this._flashQueuedNotification(data)
        break
    }
  }

  // Update the dot color and status label for an attendant
  _updateAttendantCard(data) {
    const card = document.getElementById(`attendant-status-${data.attendant_id}`)
    if (!card) return

    const dot = card.querySelector(".rounded-full.w-2")
    if (dot) {
      dot.className = `w-2 h-2 rounded-full ${this._statusDot(data.status)}`
    }
  }

  // Move an assignment card to the correct Kanban column
  _updateAssignmentCard(data) {
    const cardEl   = document.getElementById(`assignment-${data.assignment_id}`)
    const targetCol = this.cardsTargets.find(c => c.dataset.column === data.status)

    if (cardEl && targetCol) {
      targetCol.prepend(cardEl)
    }

    // Update counts
    this._recalculateCounts()
  }

  _flashQueuedNotification(data) {
    const note = document.createElement("div")
    note.className = "fixed top-4 right-4 z-50 bg-yellow-500 text-white px-4 py-3 rounded-lg shadow-lg text-sm"
    note.textContent = `Nova conversa na fila: ${data.department}`
    document.body.appendChild(note)
    setTimeout(() => note.remove(), 5000)
  }

  _recalculateCounts() {
    this.cardsTargets.forEach(cardsEl => {
      const col    = cardsEl.dataset.column
      const count  = cardsEl.querySelectorAll("[data-company-inbox-target~='card']").length
      const badge  = this.countTargets.find(b => b.dataset.column === col)
      if (badge) badge.textContent = count
    })
  }

  _statusDot(status) {
    const map = {
      available: "bg-[#25d366]",
      busy:      "bg-yellow-400",
      offline:   "bg-[#8696a0]"
    }
    return map[status] || "bg-[#8696a0]"
  }
}
