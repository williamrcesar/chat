import { Controller } from "@hotwired/stimulus"

// Mounted on each "Responder" button inside the msg-options dropdown.
// Values come from data-reply-* attributes set in the partial.
export default class extends Controller {
  static values = {
    id:        Number,
    sender:    String,
    preview:   String,
    thumb:     String,
    isSticker: Boolean
  }

  set(event) {
    event.stopPropagation()

    const banner    = document.getElementById("reply-banner")
    const nameEl    = document.getElementById("reply-banner-name")
    const textEl    = document.getElementById("reply-banner-text")
    const thumbEl   = document.getElementById("reply-banner-thumb")
    const idField   = document.getElementById("reply-to-id-field")

    if (!banner || !idField) return

    if (nameEl)  nameEl.textContent  = this.senderValue || ""
    if (textEl)  textEl.textContent  = this.previewValue || ""

    if (thumbEl) {
      const thumb = this.thumbValue
      if (thumb) {
        thumbEl.src = thumb
        thumbEl.style.display = "block"
      } else {
        thumbEl.src = ""
        thumbEl.style.display = "none"
      }
    }

    idField.value = this.idValue
    banner.style.display = "flex"

    // Scroll to and focus the input
    const input = document.querySelector("[data-chat-target='input']")
    if (input) { input.focus() }
  }
}
