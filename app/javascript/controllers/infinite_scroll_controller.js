import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      { root: this.element.closest("[data-chat-target='messages']"), threshold: 0.1 }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting && !this.loading) {
        this.loadMore()
      }
    })
  }

  async loadMore() {
    this.loading = true
    const container = this.element.closest("[data-chat-target='messages']")
    // Remember scroll height before prepending
    const scrollHeightBefore = container?.scrollHeight || 0
    const scrollTopBefore    = container?.scrollTop    || 0

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        // Use Turbo to process the stream
        Turbo.renderStreamMessage(html)

        // After render, restore scroll position so user stays in place
        requestAnimationFrame(() => {
          if (container) {
            const newScrollHeight = container.scrollHeight
            container.scrollTop = scrollTopBefore + (newScrollHeight - scrollHeightBefore)
          }
        })
      }
    } finally {
      this.loading = false
    }
  }
}
