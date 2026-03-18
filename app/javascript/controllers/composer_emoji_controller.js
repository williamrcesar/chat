import { Controller } from "@hotwired/stimulus"

// Emoji picker for the message composer with:
// - favorites row (persisted in localStorage)
// - "more" button opening a modal with all emojis
// Inserts the selected emoji into the textarea at the cursor position.
export default class extends Controller {
  static targets = ["panel", "modal", "favorites", "input"]
  static values = {
    emojis: Array
  }

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
    this.boundEsc = this.closeOnEsc.bind(this)
    this.storageKey = "chat:fav_emojis:v1"

    this.allEmojis = (this.hasEmojisValue && Array.isArray(this.emojisValue) && this.emojisValue.length > 0)
      ? this.emojisValue
      : []

    this.renderFavorites()
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("keydown", this.boundEsc)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const isHidden = this.panelTarget.classList.contains("hidden")

    this.closeAllPickers()

    if (isHidden) {
      this.panelTarget.classList.remove("hidden")
      requestAnimationFrame(() => {
        document.addEventListener("click", this.boundClose)
        document.addEventListener("keydown", this.boundEsc)
      })
    } else {
      this.close()
    }
  }

  pick(event) {
    event.preventDefault()
    event.stopPropagation()

    const emoji = event.currentTarget.dataset.emoji
    if (!emoji) return

    if (event.currentTarget.dataset.fav === "true") {
      this.toggleFavorite(emoji)
      return
    }

    const input = this.inputTarget
    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? input.value.length

    input.value = input.value.slice(0, start) + emoji + input.value.slice(end)
    const caret = start + emoji.length
    input.setSelectionRange(caret, caret)
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.focus()

    this.addFavorite(emoji)
    this.close()
  }

  openMore(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      this.lockScroll()
      requestAnimationFrame(() => {
        document.addEventListener("click", this.boundClose)
        document.addEventListener("keydown", this.boundEsc)
      })
    }
  }

  close() {
    if (this.hasPanelTarget) this.panelTarget.classList.add("hidden")
    if (this.hasModalTarget) this.modalTarget.classList.add("hidden")
    this.unlockScroll()
    document.removeEventListener("click", this.boundClose)
    document.removeEventListener("keydown", this.boundEsc)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEsc(event) {
    if (event.key === "Escape") this.close()
  }

  closeAllPickers() {
    document.querySelectorAll("[data-controller~='composer-emoji']").forEach(el => {
      el.querySelectorAll("[data-composer-emoji-target='panel']").forEach(p => p.classList.add("hidden"))
      el.querySelectorAll("[data-composer-emoji-target='modal']").forEach(m => m.classList.add("hidden"))
    })
  }

  lockScroll() {
    if (this.scrollLocked) return
    this.scrollLocked = true
    this.scrollY = window.scrollY || document.documentElement.scrollTop || 0
    document.body.style.position = "fixed"
    document.body.style.top = `-${this.scrollY}px`
    document.body.style.left = "0"
    document.body.style.right = "0"
    document.body.style.width = "100%"
  }

  unlockScroll() {
    if (!this.scrollLocked) return
    this.scrollLocked = false
    const y = this.scrollY || 0
    document.body.style.position = ""
    document.body.style.top = ""
    document.body.style.left = ""
    document.body.style.right = ""
    document.body.style.width = ""
    window.scrollTo(0, y)
  }

  renderFavorites() {
    if (!this.hasFavoritesTarget) return

    const favs = this.getFavorites()
    const base = favs.length > 0 ? favs : this.defaultFavorites()
    const uniq = Array.from(new Set(base)).filter(e => e)

    this.favoritesTarget.innerHTML = ""
    uniq.slice(0, 8).forEach(emoji => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.dataset.action = "click->composer-emoji#pick"
      btn.dataset.emoji = emoji
      btn.className = "text-xl hover:scale-125 transition-transform p-1 rounded hover:bg-[#2a3942]"
      btn.textContent = emoji
      this.favoritesTarget.appendChild(btn)
    })
  }

  getFavorites() {
    try {
      const raw = localStorage.getItem(this.storageKey)
      const parsed = JSON.parse(raw || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch {
      return []
    }
  }

  setFavorites(list) {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(list))
    } catch {
      // ignore (storage may be blocked)
    }
    this.renderFavorites()
  }

  defaultFavorites() {
    return ["👍", "❤️", "😂", "🙏", "🔥", "🎉", "😮", "😢"]
  }

  addFavorite(emoji) {
    const favs = this.getFavorites().filter(e => e !== emoji)
    favs.unshift(emoji)
    this.setFavorites(favs.slice(0, 24))
  }

  toggleFavorite(emoji) {
    const favs = this.getFavorites()
    if (favs.includes(emoji)) {
      this.setFavorites(favs.filter(e => e !== emoji))
    } else {
      favs.unshift(emoji)
      this.setFavorites(Array.from(new Set(favs)).slice(0, 24))
    }
  }
}

