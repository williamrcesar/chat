import { Controller } from "@hotwired/stimulus"

// Rola a área de mensagens até o fundo ao carregar a conversa (Turbo ou full load).
// Garante que as últimas mensagens apareçam ao clicar na conversa.
export default class extends Controller {
  connect() {
    this.scroll()
    this.scheduleScrollAfterLayout()
  }

  // Chamado por data-action="turbo:load->scroll-to-bottom#scroll" quando o Turbo termina de renderizar
  scroll() {
    const container = this.element
    if (!container) return
    container.scrollTop = container.scrollHeight
    const anchor = document.getElementById("messages-bottom")
    if (anchor) anchor.scrollIntoView({ behavior: "auto", block: "end" })
  }

  // Repete após layout (imagens, fontes) para corrigir scroll
  scheduleScrollAfterLayout() {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => this.scroll())
    })
    setTimeout(() => this.scroll(), 100)
    setTimeout(() => this.scroll(), 350)
  }
}
