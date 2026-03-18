import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["messages", "input", "form", "submitButton", "attachment", "clientMessageId"]
  static values  = { conversationId: Number, interactiveLocked: Boolean }

  connect() {
    this.scrollToBottom()
    // Repetir após o layout (imagens, etc.) para abrir a conversa já nas últimas mensagens
    requestAnimationFrame(() => {
      requestAnimationFrame(() => this.scrollToBottom())
    })
    this.setupChannel()
    this.observeNewMessages()
    this.bindVisibility()
    // Apply lock state on page load (server-rendered)
    if (this.interactiveLockedValue) {
      this.lockInput(null)
    }
  }

  disconnect() {
    this.channel?.unsubscribe()
    this.observer?.disconnect()
    clearTimeout(this.typingTimeout)
    document.removeEventListener("visibilitychange", this._visibilityHandler)
  }

  bindVisibility() {
    this._visibilityHandler = () => {
      if (document.visibilityState === "visible") this.markRead()
    }
    document.addEventListener("visibilitychange", this._visibilityHandler)
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
        this.appendMessage(data.message, data.message_id)
        if (data.message_id != null) {
          this.channel.perform("message_received", { message_id: data.message_id })
        }
        this.markRead()
        break
      case "typing":
        this.showTyping(data)
        break
      case "presence":
        this.updatePresence(data)
        break
      case "message_updated":
        // Prefer direct replace by id when we have html so status (sent/delivered/read) updates reliably
        const msgId = data.message_id ?? data["message_id"]
        const html = data.html ?? data["html"]
        if (msgId != null && html) {
          this.replaceMessage(msgId, html)
        } else if (data.turbo_stream || data["turbo_stream"]) {
          Turbo.renderStreamMessage(data.turbo_stream || data["turbo_stream"])
        }
        break
      case "message_deleted":
        this.markMessageDeleted(data.message_id)
        break
      case "reaction_update":
        this.updateReactions(data.message_id, data.html)
        if (data.notification) this.showReactionNotification(data.notification)
        break
      case "interactive_lock":
        this.lockInput(data.locked_until)
        break
      case "interactive_unlock":
        this.unlockInput()
        break
    }
  }

  appendMessage(html, messageId = null) {
    if (!this.hasMessagesTarget) return
    if (messageId != null && document.getElementById(`message_${messageId}`)) return
    this.messagesTarget.insertAdjacentHTML("beforeend", html)
    this.scrollToBottom()
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (!this._submitting) this.formTarget.requestSubmit()
    }
  }

  submitForm(event) {
    if (this._submitting) {
      event.preventDefault()
      event.stopImmediatePropagation()
      return
    }
    this._submitting = true
    if (this.hasClientMessageIdTarget) {
      this.clientMessageIdTarget.value = crypto.randomUUID()
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  resetForm() {
    this._submitting = false
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.style.height = "auto"
      // Notify voice-recorder to switch back to mic button
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
    if (this.hasAttachmentTarget) {
      this.attachmentTarget.value = ""
    }
    document.getElementById("file-preview")?.classList.add("hidden")
    document.getElementById("file-preview-content") && (document.getElementById("file-preview-content").innerHTML = "")
    // Clear reply context
    const replyField  = document.getElementById("reply-to-id-field")
    const replyBanner = document.getElementById("reply-banner")
    if (replyField)  replyField.value        = ""
    if (replyBanner) replyBanner.style.display = "none"
  }

  autoResize(event) {
    const ta = event.target
    ta.style.height = "auto"
    ta.style.height = Math.min(ta.scrollHeight, 128) + "px"
  }

  scrollToBottom() {
    const container = document.getElementById("messages-container")
    const anchor = document.getElementById("messages-bottom")
    if (container) {
      container.scrollTop = container.scrollHeight
    }
    if (anchor) {
      anchor.scrollIntoView({ behavior: "auto", block: "end" })
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

  updateReactions(messageId, html) {
    const container = document.getElementById(`reactions_${messageId}`)
    if (!container || html == null) return
    container.outerHTML = html
  }

  showReactionNotification(notification) {
    const name = notification.display_name || "Alguém"
    const emoji = notification.emoji || "👍"
    const text = `${name} curtiu ${emoji}`
    const el = document.createElement("div")
    el.className = "fixed top-4 right-4 z-50 bg-[#202c33] border border-[#2a3942] text-white px-4 py-3 rounded-lg shadow-lg text-sm flex items-center gap-2"
    el.setAttribute("role", "status")
    el.innerHTML = `<span class="text-xl">${emoji}</span><span>${text}</span>`
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 3000)
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
