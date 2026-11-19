import { Controller } from "@hotwired/stimulus"

// Minimal controller kept for forward compatibility.
// Sticker saving from conversation history is handled by msg_options_controller#saveSticker.
export default class extends Controller {
  static values = { url: String }

  save() {
    const url = this.urlValue
    if (!url) return
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    fetch(url)
      .then(r => r.blob())
      .then(blob => {
        const ext  = blob.type.includes("gif") ? "gif" : "png"
        const file = new File([blob], `sticker.${ext}`, { type: blob.type })
        const fd   = new FormData()
        fd.append("sticker[image]", file)
        return fetch("/stickers", {
          method: "POST",
          headers: { "X-CSRF-Token": csrfToken },
          body: fd
        })
      })
      .then(r => {
        if (r.ok) {
          const toast = document.createElement("div")
          toast.textContent = "Figurinha salva!"
          toast.className = "fixed bottom-24 left-1/2 -translate-x-1/2 px-4 py-2 rounded-xl text-white text-sm shadow-lg z-[600] bg-[#00a884]"
          document.body.appendChild(toast)
          setTimeout(() => toast.remove(), 2500)
        }
      })
      .catch(() => {})
  }
}
