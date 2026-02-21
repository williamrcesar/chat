import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  toggle() {
    const modal = document.getElementById("new-conversation-modal")
    modal?.classList.toggle("hidden")
  }

  close() {
    const modal = document.getElementById("new-conversation-modal")
    modal?.classList.add("hidden")
  }

  clickOutside(event) {
    if (event.target === this.element) {
      this.close()
    }
  }
}
