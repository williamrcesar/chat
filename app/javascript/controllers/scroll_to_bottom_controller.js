import { Controller } from "@hotwired/stimulus"

// Rola a área de mensagens até o fundo ao carregar a conversa (Turbo ou full load).
// Garante que as últimas mensagens apareçam ao clicar na conversa.
export default class extends Controller {
  connect() {
    // Scroll imediato + após renderização do layout (imagens, stickers, etc.)
    this.scroll()
    this.scheduleScrollAfterLayout()

    // Garantir scroll também quando Turbo termina qualquer navegação
    this._onTurboLoad = () => this.scroll()
    document.addEventListener("turbo:load",        this._onTurboLoad)
    document.addEventListener("turbo:render",      this._onTurboLoad)
    document.addEventListener("turbo:frame-load",  this._onTurboLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:load",       this._onTurboLoad)
    document.removeEventListener("turbo:render",     this._onTurboLoad)
    document.removeEventListener("turbo:frame-load", this._onTurboLoad)
  }

  // Chamado por data-action="turbo:load->scroll-to-bottom#scroll"
  scroll() {
    const container = this.element
    if (!container) return
    container.scrollTop = container.scrollHeight
    const anchor = document.getElementById("messages-bottom")
    if (anchor) anchor.scrollIntoView({ behavior: "instant", block: "end" })
  }

  // Repete após layout (imagens, fontes, stickers) para corrigir scroll
  scheduleScrollAfterLayout() {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => this.scroll())
    })
    setTimeout(() => this.scroll(), 150)
    setTimeout(() => this.scroll(), 500)
    setTimeout(() => this.scroll(), 1000)
  }
}
