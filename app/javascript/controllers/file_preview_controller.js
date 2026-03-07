import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const remove = document.getElementById("file-preview-remove")
    const input = this.element.querySelector('input[type="file"]')
    if (remove && input) {
      remove.addEventListener("click", () => this.clearPreview(input))
    }
  }

  showPreview(event) {
    const input = event.target
    const files = input?.files
    const preview = document.getElementById("file-preview")
    const content = document.getElementById("file-preview-content")

    if (!files?.length || !preview || !content) return

    preview.classList.remove("hidden")
    content.innerHTML = ""

    const fragment = document.createDocumentFragment()
    for (let i = 0; i < files.length; i++) {
      const file = files[i]
      const el = this.buildPreviewNode(file)
      if (el) fragment.appendChild(el)
    }
    content.appendChild(fragment)
  }

  buildPreviewNode(file) {
    const wrap = document.createElement("div")
    wrap.className = "flex items-center gap-2 bg-[#1f2c34] rounded-lg px-2 py-1.5 flex-shrink-0"
    if (file.type.startsWith("image/")) {
      const reader = new FileReader()
      const img = document.createElement("img")
      img.className = "h-14 w-14 object-cover rounded"
      img.alt = file.name
      const nameSpan = document.createElement("span")
      nameSpan.className = "text-white text-xs truncate max-w-[120px]"
      nameSpan.textContent = file.name
      wrap.appendChild(img)
      wrap.appendChild(nameSpan)
      reader.onload = (e) => { img.src = e.target.result }
      reader.readAsDataURL(file)
    } else {
      const icon = file.type.startsWith("audio/") ? "🎤" :
                   file.type.startsWith("video/") ? "🎥" : "📄"
      wrap.innerHTML = `
        <span class="text-xl">${icon}</span>
        <span class="text-white text-xs truncate max-w-[140px]">${file.name}</span>
        <span class="text-[#8696a0] text-xs">${this.formatSize(file.size)}</span>
      `
    }
    return wrap
  }

  clearPreview(input) {
    if (input) input.value = ""
    const preview = document.getElementById("file-preview")
    const content = document.getElementById("file-preview-content")
    if (preview) preview.classList.add("hidden")
    if (content) content.innerHTML = ""
  }

  formatSize(bytes) {
    if (bytes < 1024)       return bytes + " B"
    if (bytes < 1048576)    return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / 1048576).toFixed(1) + " MB"
  }
}
