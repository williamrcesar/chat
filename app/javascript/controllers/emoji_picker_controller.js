import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
    this.hideContextMenu()
  }

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.panelTarget.classList.contains("hidden")

    // Close all other open pickers and their context menus
    document.querySelectorAll("[data-emoji-picker-target='panel']").forEach(p => {
      p.classList.add("hidden")
      p.closest(".context-menu-bar")?.classList.remove("emoji-picker-open")
    })

    if (isHidden) {
      this.panelTarget.classList.remove("hidden")
      this.showContextMenu()
      // Defer so the same click doesn't immediately trigger closeOnOutsideClick
      requestAnimationFrame(() => {
        document.addEventListener("click", this.boundClose)
      })
    } else {
      this.hideContextMenu()
      document.removeEventListener("click", this.boundClose)
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.panelTarget.classList.add("hidden")
      this.hideContextMenu()
      document.removeEventListener("click", this.boundClose)
    }
  }

  showContextMenu() {
    const bar = this.element.closest(".context-menu-bar")
    if (bar) bar.classList.add("emoji-picker-open")
  }

  hideContextMenu() {
    const bar = this.element.closest(".context-menu-bar")
    if (bar) bar.classList.remove("emoji-picker-open")
  }
}
