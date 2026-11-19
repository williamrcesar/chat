import { Controller } from "@hotwired/stimulus"

// Valida no cliente que o áudio customizado tem no máximo 6 segundos.
export default class extends Controller {
  static values = { maxSeconds: { type: Number, default: 6 } }

  connect() {
    const input = this.element.querySelector('input[type="file"][accept*="audio"]')
    if (!input) return
    this.boundValidate = (e) => this.validateDuration(e)
    input.addEventListener("change", this.boundValidate)
  }

  disconnect() {
    const input = this.element.querySelector('input[type="file"][accept*="audio"]')
    input?.removeEventListener("change", this.boundValidate)
  }

  validateDuration(event) {
    const file = event.target.files?.[0]
    if (!file) return

    const url = URL.createObjectURL(file)
    const audio = new Audio(url)

    const cleanup = () => {
      URL.revokeObjectURL(url)
      audio.removeEventListener("loadedmetadata", onLoaded)
      audio.removeEventListener("error", onError)
    }

    const onLoaded = () => {
      const dur = audio.duration
      cleanup()
      if (dur > this.maxSecondsValue) {
        event.target.value = ""
        this.showError(`O áudio deve ter no máximo ${this.maxSecondsValue} segundos (atual: ${dur.toFixed(1)}s).`)
      } else {
        this.clearError()
      }
    }

    const onError = () => {
      cleanup()
      // Arquivo pode ser formato que o browser não suporta; deixa o backend validar
    }

    audio.addEventListener("loadedmetadata", onLoaded)
    audio.addEventListener("error", onError)
    audio.load()
  }

  showError(message) {
    this.clearError()
    const el = document.createElement("p")
    el.setAttribute("data-notification-settings-target", "error")
    el.className = "mt-2 text-amber-400 text-sm"
    el.textContent = message
    const input = this.element.querySelector('input[type="file"][accept*="audio"]')
    if (input?.parentElement) input.parentElement.appendChild(el)
  }

  clearError() {
    this.element.querySelectorAll("[data-notification-settings-target=error]").forEach((e) => e.remove())
  }
}
