import { Controller } from "@hotwired/stimulus"

// Barra de seleção de imagens: mostra quando entra em modo seleção; Descarregar seleção / Cancelar.
export default class extends Controller {
  static targets = ["count", "bar"]

  connect() {
    document.addEventListener("imageViewer:enterSelectionMode", this.show.bind(this))
  }

  disconnect() {
    document.removeEventListener("imageViewer:enterSelectionMode", this.show.bind(this))
  }

  show() {
    this.element.classList.remove("hidden")
    this.updateCount()
    const self = this
    document.querySelectorAll("[data-controller*='image-viewer'] input.image-viewer-checkbox").forEach(cb => {
      cb.removeEventListener("change", self._boundUpdateCount)
      self._boundUpdateCount = () => self.updateCount()
      cb.addEventListener("change", self._boundUpdateCount)
    })
  }

  hide() {
    document.body.classList.remove("image-selection-mode")
    document.dispatchEvent(new CustomEvent("imageViewer:exitSelectionMode"))
    this.element.classList.add("hidden")
  }

  updateCount() {
    const n = document.querySelectorAll("body.image-selection-mode [data-controller*='image-viewer'] input.image-viewer-checkbox:checked").length
    if (this.hasCountTarget) this.countTarget.textContent = n === 1 ? "1 imagem selecionada" : `${n} imagens selecionadas`
  }

  downloadSelected(event) {
    event.preventDefault()
    const wrappers = document.querySelectorAll("body.image-selection-mode [data-controller*='image-viewer'] input.image-viewer-checkbox:checked")
    const items = Array.from(wrappers).map(cb => {
      const wrap = cb.closest("[data-controller*='image-viewer']")
      return {
        url: wrap.dataset.imageViewerUrlValue || wrap.getAttribute("data-image-viewer-url-value"),
        filename: wrap.dataset.imageViewerFilenameValue || wrap.getAttribute("data-image-viewer-filename-value") || "image"
      }
    }).filter(x => x.url)
    items.forEach((item, i) => {
      const fullUrl = item.url.startsWith("http") ? item.url : `${window.location.origin}${item.url}`
      const filename = item.filename || `image-${i + 1}`
      setTimeout(() => {
        fetch(fullUrl).then(r => r.blob()).then(blob => {
          const u = URL.createObjectURL(blob)
          const a = document.createElement("a")
          a.href = u
          a.download = filename
          document.body.appendChild(a)
          a.click()
          a.remove()
          URL.revokeObjectURL(u)
        })
      }, i * 200)
    })
    this.hide()
  }

  cancel(event) {
    event.preventDefault()
    this.hide()
  }
}
