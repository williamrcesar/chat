import { Controller } from "@hotwired/stimulus"

// Popover de informações da mensagem: enviado, entregue, lido (por quem, em grupo).
export default class extends Controller {
  static targets = ["popover", "trigger"]

  connect() {
    this.boundClose = (e) => this.closeIfOutside(e)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  toggle(event) {
    event.stopPropagation()
    if (!this.hasPopoverTarget) return
    if (this.popoverTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.popoverTarget.classList.remove("hidden")
    document.addEventListener("click", this.boundClose)
  }

  close() {
    this.popoverTarget.classList.add("hidden")
    document.removeEventListener("click", this.boundClose)
  }

  closeIfOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }
}
