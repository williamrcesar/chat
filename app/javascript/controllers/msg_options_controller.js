import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this._boundOutside = this._onOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this._boundOutside)
  }

  toggle(event) {
    event.stopPropagation()
    if (!this.hasMenuTarget) return
    const open = this.menuTarget.style.display !== "none"
    if (open) {
      this._hide()
    } else {
      this._show()
    }
  }

  _show() {
    if (!this.hasMenuTarget) return
    this.menuTarget.style.display = "block"
    requestAnimationFrame(() => {
      document.addEventListener("click", this._boundOutside)
    })
  }

  _hide() {
    if (!this.hasMenuTarget) return
    this.menuTarget.style.display = "none"
    document.removeEventListener("click", this._boundOutside)
  }

  _onOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this._hide()
    }
  }

  copy(event) {
    event.stopPropagation()
    const text = this.element.dataset.msgText || ""
    if (text) {
      navigator.clipboard.writeText(text).catch(() => {
        const ta = document.createElement("textarea")
        ta.value = text
        document.body.appendChild(ta)
        ta.select()
        document.execCommand("copy")
        document.body.removeChild(ta)
      })
    }
    this._hide()
  }

  download(event) {
    event.stopPropagation()
    const url = this.element.dataset.msgAttachmentUrl
    if (url) {
      const a = document.createElement("a")
      a.href = url
      a.download = ""
      a.target = "_blank"
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
    }
    this._hide()
  }

  saveSticker(event) {
    event.stopPropagation()
    const url = this.element.dataset.msgAttachmentUrl
    if (!url) { this._hide(); return }

    fetch(url)
      .then(r => r.blob())
      .then(blob => {
        const ext = blob.type.includes("gif") ? "gif" : "png"
        const file = new File([blob], `sticker.${ext}`, { type: blob.type })
        const fd = new FormData()
        fd.append("sticker[image]", file)
        return fetch("/stickers", {
          method: "POST",
          headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" },
          body: fd
        })
      })
      .then(r => {
        if (r.ok) {
          this._showToast("Figurinha salva!")
        } else {
          this._showToast("Não foi possível salvar", true)
        }
      })
      .catch(() => this._showToast("Erro ao salvar figurinha", true))

    this._hide()
  }

  _showToast(msg, error = false) {
    const toast = document.createElement("div")
    toast.textContent = msg
    toast.className = `fixed bottom-24 left-1/2 -translate-x-1/2 px-4 py-2 rounded-xl text-white text-sm shadow-lg z-[600] transition-opacity ${error ? "bg-red-600" : "bg-[#00a884]"}`
    document.body.appendChild(toast)
    setTimeout(() => { toast.style.opacity = "0"; setTimeout(() => toast.remove(), 300) }, 2500)
  }
}
