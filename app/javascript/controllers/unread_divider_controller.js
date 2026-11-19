import { Controller } from "@hotwired/stimulus"

// Esconde o aviso "X mensagens não lidas" após 1 minuto.
export default class extends Controller {
  static values = { delayMs: { type: Number, default: 60_000 } }

  connect() {
    this.timeoutId = setTimeout(() => this.hide(), this.delayMsValue)
  }

  disconnect() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
  }

  hide() {
    this.element.classList.add("hidden")
  }
}
