import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.addEventListener("visibilitychange", this.handleVisibility.bind(this))
    window.addEventListener("beforeunload", this.handleUnload.bind(this))
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibility.bind(this))
    window.removeEventListener("beforeunload", this.handleUnload.bind(this))
  }

  handleVisibility() {
    if (document.visibilityState === "visible") {
      this.ping()
    }
  }

  handleUnload() {
    // Presence will be updated server-side when cable disconnects
  }

  ping() {
    fetch("/up").catch(() => {})
  }
}
