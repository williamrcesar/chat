import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["column", "cards", "count", "card"]
  static values  = { campaignId: Number }

  connect() {
    if (!this.hasCampaignIdValue) return

    this._consumer = createConsumer()
    this._subscription = this._consumer.subscriptions.create(
      { channel: "KanbanChannel", campaign_id: this.campaignIdValue },
      { received: (data) => this._handleUpdate(data) }
    )
  }

  disconnect() {
    this._subscription?.unsubscribe()
    this._consumer?.disconnect()
  }

  _handleUpdate(data) {
    if (data.type !== "delivery_update") return

    const { delivery_id, status, recipient_name, recipient_nick, clicked_button, clicked_list } = data

    // Remove card from current column
    const existingCard = this.element.querySelector(`#delivery-${delivery_id}`)
    const oldColumn = existingCard?.closest("[data-column]")?.dataset.column
    existingCard?.remove()

    // Update count on old column
    if (oldColumn) this._updateCount(oldColumn)

    // Build and insert card in new column
    const newCard = this._buildCard(delivery_id, recipient_name, recipient_nick, clicked_button, clicked_list, status)
    const targetCards = this.element.querySelector(`[data-kanban-target='cards'][data-column='${status}']`)
    if (targetCards) {
      targetCards.insertAdjacentHTML("afterbegin", newCard)
      this._updateCount(status)

      // Flash animation
      const card = targetCards.querySelector(`#delivery-${delivery_id}`)
      card?.classList.add("ring-2", "ring-[#00a884]")
      setTimeout(() => card?.classList.remove("ring-2", "ring-[#00a884]"), 2000)
    }
  }

  _updateCount(column) {
    const cards = this.element.querySelector(`[data-kanban-target='cards'][data-column='${column}']`)
    const countEl = this.element.querySelector(`[data-kanban-target='count'][data-column='${column}']`)
    if (cards && countEl) {
      countEl.textContent = cards.children.length
    }
  }

  _buildCard(id, name, nick, clickedButton, clickedList, status) {
    const initial = (name || "?")[0].toUpperCase()
    const clickInfo = clickedButton
      ? `<div class="mt-2 bg-[#25d366]/10 rounded px-2 py-1"><p class="text-[#25d366] text-xs">Clicou: "${clickedButton}"</p></div>`
      : clickedList
      ? `<div class="mt-2 bg-[#25d366]/10 rounded px-2 py-1"><p class="text-[#25d366] text-xs">Lista: "${clickedList}"</p></div>`
      : ""

    const nickHtml = nick ? `<p class="text-[#8696a0] text-xs">@${nick}</p>` : ""

    return `
      <div class="bg-[#202c33] rounded-lg p-3 shadow transition-all"
           id="delivery-${id}"
           data-kanban-target="card"
           data-delivery-id="${id}">
        <div class="flex items-center gap-2">
          <div class="w-8 h-8 rounded-full bg-[#6a7175] flex items-center justify-center text-white font-semibold text-xs flex-shrink-0">
            ${initial}
          </div>
          <div class="min-w-0">
            <p class="text-white text-xs font-semibold truncate">${name}</p>
            ${nickHtml}
          </div>
        </div>
        ${clickInfo}
      </div>`
  }
}
