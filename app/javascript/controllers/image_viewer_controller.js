import { Controller } from "@hotwired/stimulus"

// Visualizador de imagem: clique abre em tela cheia; Descarregar; "Selecionar mais" ativa modo de seleção.
export default class extends Controller {
  static targets = ["img", "checkbox"]
  static values = { url: String, filename: String }

  connect() {
    this.boundClose = () => this.closeOverlay()
    this.boundKeydown = (e) => e.key === "Escape" && this.closeOverlay()
    document.addEventListener("imageViewer:enterSelectionMode", this.showCheckbox.bind(this))
    document.addEventListener("imageViewer:exitSelectionMode", this.hideCheckbox.bind(this))
  }

  disconnect() {
    document.removeEventListener("imageViewer:enterSelectionMode", this.showCheckbox.bind(this))
    document.removeEventListener("imageViewer:exitSelectionMode", this.hideCheckbox.bind(this))
    this.removeOverlay()
  }

  open(event) {
    if (document.body.classList.contains("image-selection-mode")) return
    if (event.target.type === "checkbox" || event.target.closest?.("input[type=checkbox]")) return
    event.preventDefault()
    event.stopPropagation()
    this.ensureOverlay()
    const img = this.overlay.querySelector(".image-viewer-fullscreen-img")
    const url = this.urlValue.startsWith("http") ? this.urlValue : `${window.location.origin}${this.urlValue}`
    img.src = url
    img.alt = this.filenameValue
    this.overlay.dataset.currentUrl = this.urlValue
    this.overlay.dataset.currentFilename = this.filenameValue
    this.resetZoom()
    this.overlay.classList.remove("hidden")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.boundKeydown)
  }

  closeOverlay() {
    if (!this.overlay) return
    this.overlay.classList.add("hidden")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.boundKeydown)
  }

  selectMore() {
    this.closeOverlay()
    document.body.classList.add("image-selection-mode")
    document.dispatchEvent(new CustomEvent("imageViewer:enterSelectionMode"))
  }

  showCheckbox() {
    if (this.hasCheckboxTarget) this.checkboxTarget.classList.remove("hidden")
  }

  hideCheckbox() {
    if (this.hasCheckboxTarget) {
      this.checkboxTarget.classList.add("hidden")
      this.checkboxTarget.checked = false
    }
  }

  get overlay() {
    return document.getElementById("image-viewer-overlay")
  }

  ensureOverlay() {
    if (this.overlay) return
    const self = this
    const div = document.createElement("div")
    div.id = "image-viewer-overlay"
    div.className = "hidden fixed inset-0 z-[100] bg-black/95 flex flex-col items-center justify-center p-4"
    div.innerHTML = `
      <div class="image-viewer-zoom-area flex-1 min-h-0 w-full flex items-center justify-center overflow-hidden cursor-grab touch-none select-none" style="touch-action: none;">
        <div class="image-viewer-image-wrapper inline-block transition-transform duration-150 origin-center" style="will-change: transform;">
          <img class="image-viewer-fullscreen-img max-w-full max-h-[85vh] max-w-[90vw] object-contain rounded pointer-events-none" alt="" draggable="false">
        </div>
      </div>
      <div class="flex gap-3 mt-4 flex-wrap justify-center items-center flex-shrink-0">
        <button type="button" class="image-viewer-btn-zoom-out p-2 rounded-lg bg-[#2a3942] text-white hover:bg-[#3d4a52] transition-colors" title="Menos zoom">−</button>
        <span class="image-viewer-zoom-label text-[#d1d7db] text-sm min-w-[4rem] text-center">100%</span>
        <button type="button" class="image-viewer-btn-zoom-in p-2 rounded-lg bg-[#2a3942] text-white hover:bg-[#3d4a52] transition-colors" title="Mais zoom">+</button>
        <span class="w-px h-6 bg-[#3d4a52]"></span>
        <button type="button" class="image-viewer-btn-close px-4 py-2 rounded-lg bg-[#2a3942] text-white hover:bg-[#3d4a52] transition-colors">Fechar</button>
        <button type="button" class="image-viewer-btn-download px-4 py-2 rounded-lg bg-[#00a884] text-white hover:bg-[#02966f] transition-colors">Descarregar</button>
        <button type="button" class="image-viewer-btn-select px-4 py-2 rounded-lg bg-[#2a3942] text-white hover:bg-[#3d4a52] transition-colors">Selecionar mais imagens</button>
      </div>
    `
    div._zoomState = { scale: 1, panX: 0, panY: 0 }
    const zoomArea = div.querySelector(".image-viewer-zoom-area")
    const wrapper = div.querySelector(".image-viewer-image-wrapper")
    const img = div.querySelector(".image-viewer-fullscreen-img")
    const zoomLabel = div.querySelector(".image-viewer-zoom-label")

    function applyTransform() {
      const { scale, panX, panY } = div._zoomState
      wrapper.style.transform = `translate(${panX}px, ${panY}px) scale(${scale})`
      zoomLabel.textContent = `${Math.round(scale * 100)}%`
    }

    function zoomAt(delta, clientX, clientY) {
      const rect = zoomArea.getBoundingClientRect()
      const centerX = clientX != null ? clientX - rect.left - rect.width / 2 : 0
      const centerY = clientY != null ? clientY - rect.top - rect.height / 2 : 0
      const s0 = div._zoomState.scale
      const s1 = Math.min(4, Math.max(0.25, s0 * (delta > 0 ? 1.25 : 0.8)))
      const f = s1 / s0
      div._zoomState.panX = centerX - (centerX - div._zoomState.panX) * f
      div._zoomState.panY = centerY - (centerY - div._zoomState.panY) * f
      div._zoomState.scale = s1
      applyTransform()
    }

    zoomArea.addEventListener("click", (e) => { if (e.target === zoomArea) self.closeOverlay() })
    img.addEventListener("click", (e) => e.stopPropagation())
    img.addEventListener("dblclick", () => self.resetZoom())
    zoomArea.addEventListener("wheel", (e) => { e.preventDefault(); zoomAt(-e.deltaY, e.clientX, e.clientY) }, { passive: false })

    let dragStart = null
    zoomArea.addEventListener("mousedown", (e) => {
      if (e.target !== zoomArea && !zoomArea.contains(e.target)) return
      if (e.button !== 0) return
      dragStart = { x: e.clientX - div._zoomState.panX, y: e.clientY - div._zoomState.panY }
      zoomArea.classList.add("cursor-grabbing")
    })
    document.addEventListener("mousemove", (e) => {
      if (!dragStart) return
      div._zoomState.panX = e.clientX - dragStart.x
      div._zoomState.panY = e.clientY - dragStart.y
      applyTransform()
    })
    document.addEventListener("mouseup", () => {
      dragStart = null
      zoomArea.classList.remove("cursor-grabbing")
    })

    div.querySelector(".image-viewer-btn-zoom-in").addEventListener("click", () => { zoomAt(1); applyTransform() })
    div.querySelector(".image-viewer-btn-zoom-out").addEventListener("click", () => { zoomAt(-1); applyTransform() })
    div.querySelector(".image-viewer-btn-close").addEventListener("click", () => self.closeOverlay())
    div.querySelector(".image-viewer-btn-download").addEventListener("click", () => {
      const url = div.dataset.currentUrl
      const filename = div.dataset.currentFilename || "image"
      if (!url) return
      const fullUrl = url.startsWith("http") ? url : `${window.location.origin}${url}`
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
    })
    div.querySelector(".image-viewer-btn-select").addEventListener("click", () => self.selectMore())
    document.body.appendChild(div)
  }

  resetZoom() {
    const ov = this.overlay
    if (!ov || !ov._zoomState) return
    ov._zoomState.scale = 1
    ov._zoomState.panX = 0
    ov._zoomState.panY = 0
    const wrapper = ov.querySelector(".image-viewer-image-wrapper")
    const zoomLabel = ov.querySelector(".image-viewer-zoom-label")
    if (wrapper) wrapper.style.transform = "translate(0, 0) scale(1)"
    if (zoomLabel) zoomLabel.textContent = "100%"
  }

  removeOverlay() {
    const ov = this.overlay
    if (ov) ov.remove()
  }
}
