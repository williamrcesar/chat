import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.panelTarget.classList.contains("hidden")

    // Close all other open pickers first
    document.querySelectorAll("[data-emoji-picker-target='panel']").forEach(p => {
      p.classList.add("hidden")
    })

    if (isHidden) {
      this.panelTarget.classList.remove("hidden")
      document.addEventListener("click", this.boundClose)
    } else {
      document.removeEventListener("click", this.boundClose)
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.panelTarget.classList.add("hidden")
      document.removeEventListener("click", this.boundClose)
    }
  }
}
