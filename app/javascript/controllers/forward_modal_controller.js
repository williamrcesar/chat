import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { messageId: Number, conversationId: Number }

  open() {
    let modal = document.getElementById("forward-modal")
    if (!modal) return

    // Set the message id in the hidden field
    const hiddenField = modal.querySelector("[name='message_id']")
    if (hiddenField) hiddenField.value = this.messageIdValue

    // Update the form action
    const form = modal.querySelector("form")
    if (form) {
      const base = form.dataset.baseAction
      form.action = base.replace("__CONV__", this.conversationIdValue)
    }

    modal.classList.remove("hidden")
  }

  static close() {
    document.getElementById("forward-modal")?.classList.add("hidden")
  }
}
