import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  filter(event) {
    const query = event.target.value.toLowerCase()
    const items = this.element.querySelectorAll(".conversation-item")

    items.forEach((item) => {
      const name = item.dataset.name || ""
      item.style.display = name.includes(query) ? "" : "none"
    })
  }
}
