import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "input", "results"]
  static values  = { url: String }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    if (!this.panelTarget.classList.contains("hidden")) {
      this.inputTarget?.focus()
    }
  }

  close() {
    this.panelTarget.classList.add("hidden")
  }

  async search() {
    const q = this.inputTarget.value.trim()
    if (q.length < 2) {
      this.resultsTarget.innerHTML = ""
      return
    }

    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(async () => {
      const url = `${this.urlValue}?q=${encodeURIComponent(q)}`
      const response = await fetch(url, {
        headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
      })
      if (response.ok) {
        this.resultsTarget.innerHTML = await response.text()
      }
    }, 300)
  }
}
