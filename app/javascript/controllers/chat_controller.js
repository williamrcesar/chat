import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "input", "form", "submitButton", "attachment"]
  static values  = { conversationId: Number, interactiveLocked: Boolean }

  connect() {
    this.scrollToBottom()
    this.setupChannel()
    this.observeNewMessages()
    // Apply lock state on page load (server-rendered)
    if (this.interactiveLockedValue) {
      this.lockInput(null)
    }
  }

  disconnect() {
    this.channel?.unsubscribe()
    this.observer?.disconnect()
    clearTimeout(this.typingTimeout)
  }

  setupChannel() {
    const consumer = createConsumer()
    this.channel = consumer.subscriptions.create(
      { channel: "ChatChannel", conversation_id: this.conversationIdValue },
      { received: (data) => this.handleReceived(data) }
    )
  }

  handleReceived(data) {
    switch (data.type) {
      case "new_message":
        this.appendMessage(data.message)
        this.markRead()
        break
      case "typing":
        this.showTyping(data)
        break
      case "presence":
        this.updatePresence(data)
        break
      case "message_updated":
        this.replaceMessage(data.message_id, data.html)
        break
      case "message_deleted":
        this.markMessageDeleted(data.message_id)
        break
      case "reaction_update":
        this.updateReactions(data.message_id, data.reactions)
        break
      case "interactive_lock":
        this.lockInput(data.locked_until)
        break
      case "interactive_unlock":
        this.unlockInput()
        break
    }
  }

  appendMessage(html) {
    if (!this.hasMessagesTarget) return
    this.messagesTarget.insertAdjacentHTML("beforeend", html)
    this.scrollToBottom()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.formTarget.requestSubmit()
    }
  }

  submitForm() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  resetForm() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.style.height = "auto"
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
    if (this.hasAttachmentTarget) {
      this.attachmentTarget.value = ""
    }
    document.getElementById("file-preview")?.classList.add("hidden")
    document.getElementById("file-preview-content") && (document.getElementById("file-preview-content").innerHTML = "")
  }

  autoResize(event) {
    const ta = event.target
    ta.style.height = "auto"
    ta.style.height = Math.min(ta.scrollHeight, 128) + "px"
  }

  scrollToBottom() {
    const anchor = document.getElementById("messages-bottom")
    if (anchor) {
      anchor.scrollIntoView({ behavior: "auto" })
    } else if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  observeNewMessages() {
    if (!this.hasMessagesTarget) return
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.messagesTarget, { childList: true })
  }

  markRead() {
    this.channel?.perform("mark_read", {})
  }

  showTyping(data) {
    const indicator = document.getElementById("typing-indicator")
    const nameEl    = document.getElementById("typing-user-name")
    if (!indicator || !nameEl) return

    if (data.typing) {
      nameEl.textContent = data.user_name
      indicator.classList.remove("hidden")
      clearTimeout(this.typingTimeout)
      this.typingTimeout = setTimeout(() => {
        indicator.classList.add("hidden")
      }, 3000)
    } else {
      indicator.classList.add("hidden")
    }
  }

  updatePresence(data) {
    const statusEl = document.getElementById("contact-status")
    if (statusEl) {
      statusEl.textContent = data.online ? "online" : (data.last_seen || "offline")
    }
  }

  replaceMessage(messageId, html) {
    const el = document.getElementById(`message_${messageId}`)
    if (el) el.outerHTML = html
  }

  markMessageDeleted(messageId) {
    // Will be replaced by a broadcast_deletion_update call from the model
    const el = document.getElementById(`message_${messageId}`)
    if (el) el.classList.add("opacity-50")
  }

  updateReactions(messageId, reactions) {
    const container = document.getElementById(`reactions_${messageId}`)
    if (!container) return
    if (Object.keys(reactions).length === 0) {
      container.innerHTML = ""
      return
    }
    const html = Object.entries(reactions).map(([emoji, count]) =>
      `<span class="flex items-center gap-0.5 bg-[#202c33] border border-[#2a3942] rounded-full px-2 py-0.5 text-xs">
        <span>${emoji}</span><span class="text-[#8696a0]">${count}</span>
      </span>`
    ).join("")
    container.innerHTML = html
  }

  // Called by typing_controller
  broadcastTyping(typing) {
    this.channel?.perform("typing", { typing })
  }

  // Interactive message lock — disable text input until button/list is clicked
  lockInput(lockedUntil) {
    if (!this.hasInputTarget) return

    this.inputTarget.disabled = true
    this.inputTarget.placeholder = "Clique em um botão acima para responder..."
    this.inputTarget.classList.add("opacity-50", "cursor-not-allowed")

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }

    this._showInteractiveLockOverlay(lockedUntil)
  }

  unlockInput() {
    if (!this.hasInputTarget) return

    this.inputTarget.disabled = false
    this.inputTarget.placeholder = "Digite uma mensagem"
    this.inputTarget.classList.remove("opacity-50", "cursor-not-allowed")

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }

    document.getElementById("interactive-lock-overlay")?.remove()
  }

  _showInteractiveLockOverlay(lockedUntil) {
    const existing = document.getElementById("interactive-lock-overlay")
    if (existing) return

    const overlay = document.createElement("div")
    overlay.id = "interactive-lock-overlay"
    overlay.className = "absolute bottom-0 left-0 right-0 bg-[#111b21]/90 backdrop-blur-sm flex items-center justify-center gap-2 py-2 px-4 text-sm text-[#8696a0] z-10"
    overlay.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-[#00a884]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5zM9 7H4l5-5v5zm7 0V3m-4 18v-4m4 4h-4m4 0l4-4" />
      </svg>
      Selecione uma opção acima para responder
    `

    const inputArea = this.inputTarget.closest(".relative") || this.inputTarget.parentElement
    inputArea.style.position = "relative"
    inputArea.appendChild(overlay)
  }
}
