import { Controller } from "@hotwired/stimulus"

// Attached to a marketing message bubble that has buttons or lists.
// When the user clicks a button/list row → POST to the delivery endpoint,
// then dispatch an event so chat_controller can unlock the input.
export default class extends Controller {
  static targets = ["button", "listRow"]
  static values  = { deliveryId: Number, locked: Boolean }

  connect() {
    // Visual indicator if still locked
    if (this.lockedValue) this._showLockedIndicator()
  }

  async clickButton(event) {
    const btn   = event.currentTarget
    const label = btn.dataset.buttonLabel

    btn.disabled = true
    btn.classList.add("opacity-50")

    try {
      const resp = await fetch(`/marketing/deliveries/${this.deliveryIdValue}/button_click`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ button_label: label })
      })

      if (resp.ok) {
        this._markClicked(btn, label)
        this.dispatch("clicked", { detail: { label } })
      }
    } catch (err) {
      btn.disabled = false
      btn.classList.remove("opacity-50")
    }
  }

  async clickListRow(event) {
    const row   = event.currentTarget
    const rowId = row.dataset.rowId

    row.classList.add("opacity-50", "pointer-events-none")

    try {
      const resp = await fetch(`/marketing/deliveries/${this.deliveryIdValue}/list_click`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
        },
        body: JSON.stringify({ row_id: rowId })
      })

      if (resp.ok) {
        this._markListClicked(row, rowId)
        this.dispatch("clicked", { detail: { rowId } })
      }
    } catch (err) {
      row.classList.remove("opacity-50", "pointer-events-none")
    }
  }

  _markClicked(btn, label) {
    this.buttonTargets.forEach(b => {
      b.disabled = true
      b.classList.add("opacity-40")
    })
    btn.classList.remove("opacity-40")
    btn.classList.add("bg-[#25d366]/20", "border-[#25d366]", "text-[#25d366]")
    btn.disabled = false
  }

  _markListClicked(row, rowId) {
    this.listRowTargets.forEach(r => r.classList.add("opacity-40", "pointer-events-none"))
    row.classList.remove("opacity-40", "pointer-events-none")
    row.classList.add("bg-[#25d366]/10", "text-[#25d366]")
  }

  _showLockedIndicator() {
    // The chat_controller handles the actual input lock.
    // This just adds a visual border to the bubble.
    this.element.classList.add("ring-1", "ring-[#00a884]/40", "ring-offset-1", "ring-offset-[#202c33]")
  }
}
