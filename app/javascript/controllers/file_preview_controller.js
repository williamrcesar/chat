import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  showPreview(event) {
    const file    = event.target.files[0]
    const preview = document.getElementById("file-preview")
    const content = document.getElementById("file-preview-content")
    const remove  = document.getElementById("file-preview-remove")

    if (!file || !preview || !content) return

    preview.classList.remove("hidden")

    if (file.type.startsWith("image/")) {
      const reader = new FileReader()
      reader.onload = (e) => {
        content.innerHTML = `
          <img src="${e.target.result}" class="h-16 w-16 object-cover rounded-lg" />
          <span class="text-white text-sm ml-2 truncate">${file.name}</span>
        `
      }
      reader.readAsDataURL(file)
    } else {
      const icon = file.type.startsWith("audio/") ? "🎤" :
                   file.type.startsWith("video/") ? "🎥" : "📄"
      content.innerHTML = `
        <span class="text-2xl">${icon}</span>
        <span class="text-white text-sm ml-2 truncate">${file.name}</span>
        <span class="text-[#8696a0] text-xs ml-auto">${this.formatSize(file.size)}</span>
      `
    }

    remove?.addEventListener("click", () => {
      event.target.value = ""
      preview.classList.add("hidden")
      content.innerHTML = ""
    }, { once: true })
  }

  formatSize(bytes) {
    if (bytes < 1024)       return bytes + " B"
    if (bytes < 1048576)    return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / 1048576).toFixed(1) + " MB"
  }
}
