import { Controller } from "@hotwired/stimulus"

// Limita altura do texto da mensagem; "mostrar mais" / "mostrar menos" para expandir.
export default class extends Controller {
  static targets = ["content", "toggle", "label"]

  connect() {
    this.maxHeightCollapsed = "10rem"
    requestAnimationFrame(() => this.updateVisibility())
  }

  toggle() {
    const content = this.contentTarget
    const isExpanded = content.dataset.expanded === "true"
    if (isExpanded) {
      content.style.maxHeight = this.maxHeightCollapsed
      content.dataset.expanded = "false"
      this.labelTarget.textContent = "mostrar mais"
    } else {
      content.style.maxHeight = `${content.scrollHeight}px`
      content.dataset.expanded = "true"
      this.labelTarget.textContent = "mostrar menos"
    }
  }

  updateVisibility() {
    if (!this.hasContentTarget || !this.hasToggleTarget) return
    const content = this.contentTarget
    const needsToggle = content.scrollHeight > content.clientHeight
    if (needsToggle) {
      this.toggleTarget.classList.remove("hidden")
      content.dataset.expanded = "false"
    } else {
      this.toggleTarget.classList.add("hidden")
    }
  }
}
