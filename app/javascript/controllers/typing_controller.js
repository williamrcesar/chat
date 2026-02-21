import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.isTyping = false
    this.timeout  = null
    // Find the chat controller on the page to access its ActionCable channel
    this.chatController = this.application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller~='chat']"),
      "chat"
    )
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  handleTyping() {
    if (!this.chatController) return

    if (!this.isTyping) {
      this.isTyping = true
      this.chatController.broadcastTyping(true)
    }

    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.isTyping = false
      this.chatController?.broadcastTyping(false)
    }, 2000)
  }
}
