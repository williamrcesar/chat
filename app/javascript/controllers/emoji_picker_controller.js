import { Controller } from "@hotwired/stimulus"

// Each message renders a data-controller="emoji-picker" wrapper.
// The panel (quick bar) lives inside it; the modal div is also inside but gets
// teleported to <body> on open so position:fixed works without any ancestor
// transform/overflow interference.
export default class extends Controller {
  static targets = ["panel", "modal"]

  connect() {
    this.boundClose     = this.closeOnOutsideClick.bind(this)
    this.boundEsc       = this.closeOnEsc.bind(this)
    this.boundSubmitEnd = this.onSubmitEnd.bind(this)
    this._modalMoved    = false
    this._modalEl       = null  // saved reference, survives teleport
  }

  disconnect() {
    document.removeEventListener("click",            this.boundClose)
    document.removeEventListener("keydown",          this.boundEsc)
    document.removeEventListener("turbo:submit-end", this.boundSubmitEnd)
    this.hideContextMenu()
    this.unlockScroll()
    // Remove the teleported modal from body when the message is removed
    if (this._modalMoved && this._modalEl && this._modalEl.parentNode === document.body) {
      document.body.removeChild(this._modalEl)
    }
  }

  // ── Quick bar (panel) ──────────────────────────────────────────────────────

  toggle(event) {
    event.stopPropagation()
    const isHidden = this.panelTarget.classList.contains("hidden")

    // close every other open panel/modal
    document.querySelectorAll("[data-emoji-picker-target='panel']").forEach(p => p.classList.add("hidden"))
    this._hideModal()

    if (isHidden) {
      this.panelTarget.classList.remove("hidden")
      this.showContextMenu()
      requestAnimationFrame(() => {
        document.addEventListener("click",   this.boundClose)
        document.addEventListener("keydown", this.boundEsc)
      })
    } else {
      this.close()
    }
  }

  // ── Full modal ─────────────────────────────────────────────────────────────

  openMore(event) {
    event.preventDefault()
    event.stopPropagation()

    // Hide quick bar first
    this.panelTarget.classList.add("hidden")
    this.hideContextMenu()

    // Grab modal element — before first teleport it's still a Stimulus target;
    // after teleport we use the saved reference.
    if (!this._modalMoved) {
      if (!this.hasModalTarget) return
      const modal = this.modalTarget
      this._modalEl = modal

      // Bind close handlers directly (data-action won't work outside controller element)
      this._boundCloseModal = () => this._hideModal()
      const overlay  = modal.querySelector(".reaction-modal-overlay")
      const closeBtn = modal.querySelector(".reaction-modal-close")
      if (overlay)  overlay.addEventListener("click",  this._boundCloseModal)
      if (closeBtn) closeBtn.addEventListener("click", this._boundCloseModal)

      document.body.appendChild(modal)
      this._modalMoved = true
    }

    if (!this._modalEl) return
    this._modalEl.classList.remove("hidden")
    this.lockScroll()

    document.addEventListener("keydown",          this.boundEsc)
    document.addEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  // ── Close ──────────────────────────────────────────────────────────────────

  close(event) {
    if (event) { event.preventDefault(); event.stopPropagation() }
    if (this.hasPanelTarget) this.panelTarget.classList.add("hidden")
    this._hideModal()
    this.hideContextMenu()
    document.removeEventListener("click",   this.boundClose)
    document.removeEventListener("keydown", this.boundEsc)
  }

  _hideModal() {
    const modal = this._modalEl || (this.hasModalTarget ? this.modalTarget : null)
    if (modal) modal.classList.add("hidden")
    this.unlockScroll()
    document.removeEventListener("keydown",          this.boundEsc)
    document.removeEventListener("turbo:submit-end", this.boundSubmitEnd)
  }

  onSubmitEnd() {
    this._hideModal()
  }

  closeOnOutsideClick(event) {
    // Only close the panel (quick bar) on outside click; modal has its own close handlers
    const modal = this._modalEl || (this.hasModalTarget ? this.modalTarget : null)
    if (modal && !modal.classList.contains("hidden")) return
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  showContextMenu() {
    const bar = this.element.querySelector(".context-menu-bar") || this.element.closest(".context-menu-bar")
    if (bar) bar.classList.add("emoji-picker-open")
  }

  hideContextMenu() {
    const bar = this.element.querySelector(".context-menu-bar") || this.element.closest(".context-menu-bar")
    if (bar) bar.classList.remove("emoji-picker-open")
  }

  lockScroll() {
    if (this.scrollLocked) return
    this.scrollLocked = true
    this.scrollY = window.scrollY || document.documentElement.scrollTop || 0
    document.body.style.position = "fixed"
    document.body.style.top      = `-${this.scrollY}px`
    document.body.style.left     = "0"
    document.body.style.right    = "0"
    document.body.style.width    = "100%"
  }

  unlockScroll() {
    if (!this.scrollLocked) return
    this.scrollLocked = false
    const y = this.scrollY || 0
    document.body.style.position = ""
    document.body.style.top      = ""
    document.body.style.left     = ""
    document.body.style.right    = ""
    document.body.style.width    = ""
    window.scrollTo(0, y)
  }
}
