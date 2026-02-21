import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "headerText", "headerImage",
    "buttonsList", "buttonRow",
    "listSections", "listSection",
    "previewBubble", "previewBody", "previewHeader", "previewFooter"
  ]

  connect() {
    this._buttonCount = this.buttonRowTargets.length
    this._sectionCount = this.listSectionTargets.length
  }

  // Switch header type (none/text/image)
  updateHeader(event) {
    const val = event.target.value
    this.headerTextTargets.forEach(el => el.classList.toggle("hidden", val !== "text"))
    this.headerImageTargets.forEach(el => el.classList.toggle("hidden", val !== "image"))
  }

  // Live preview update
  updatePreview(event) {
    const field = event.target
    if (field.name.includes("[body]") && this.hasPreviewBodyTarget) {
      this.previewBodyTarget.textContent = field.value || "Corpo da mensagem..."
    }
    if (field.name.includes("[header_text]") && this.hasPreviewHeaderTarget) {
      this.previewHeaderTarget.textContent = field.value
    }
    if (field.name.includes("[footer]") && this.hasPreviewFooterTarget) {
      this.previewFooterTarget.textContent = field.value
    }
  }

  // Add a new button row
  addButton() {
    if (this._buttonCount >= 3) {
      alert("Máximo de 3 botões por template.")
      return
    }
    const index = this._buttonCount
    const html = this._buttonRowHTML(index)
    this.buttonsListTarget.insertAdjacentHTML("beforeend", html)
    this._buttonCount++
  }

  // Remove a button row
  removeButton(event) {
    const row = event.target.closest("[data-template-builder-target='buttonRow']")
    row?.remove()
    this._reindexButtons()
  }

  // Add a new list section
  addListSection() {
    const index = this._sectionCount
    const html = this._listSectionHTML(index)
    this.listSectionsTarget.insertAdjacentHTML("beforeend", html)
    this._sectionCount++
  }

  // Remove a list section
  removeListSection(event) {
    const section = event.target.closest("[data-template-builder-target='listSection']")
    section?.remove()
  }

  // Add a row to a list section
  addListRow(event) {
    const sectionIndex = event.currentTarget.dataset.sectionIndex
    const section = event.currentTarget.closest("[data-template-builder-target='listSection']")
    const existingRows = section.querySelectorAll("input[name*='[rows]']")
    // Count unique row indices
    const rowIndices = new Set()
    existingRows.forEach(el => {
      const m = el.name.match(/\[rows\]\[(\d+)\]/)
      if (m) rowIndices.add(m[1])
    })
    const rowIndex = rowIndices.size
    const html = this._listRowHTML(sectionIndex, rowIndex)
    const addBtn = event.currentTarget
    addBtn.insertAdjacentHTML("beforebegin", html)
  }

  // ── Private helpers ──────────────────────────────────────────

  _buttonRowHTML(index) {
    return `
      <div class="flex gap-2 items-center" data-template-builder-target="buttonRow">
        <input type="text"
               name="marketing_template[buttons][${index}][label]"
               placeholder="Texto do botão"
               class="flex-1 bg-[#2a3942] text-white placeholder-[#8696a0] rounded-lg px-3 py-2 text-sm outline-none border border-transparent focus:border-[#00a884]">
        <select name="marketing_template[buttons][${index}][type]"
                class="bg-[#2a3942] text-[#d1d7db] rounded-lg px-2 py-2 text-xs outline-none border border-transparent focus:border-[#00a884]">
          <option value="quick_reply">Resposta</option>
          <option value="url">URL</option>
          <option value="phone">Telefone</option>
        </select>
        <input type="text"
               name="marketing_template[buttons][${index}][value]"
               placeholder="Valor (URL ou tel)"
               class="flex-1 bg-[#2a3942] text-white placeholder-[#8696a0] rounded-lg px-3 py-2 text-sm outline-none border border-transparent focus:border-[#00a884]">
        <button type="button"
                data-action="click->template-builder#removeButton"
                class="text-[#8696a0] hover:text-red-400 p-1 transition-colors flex-shrink-0">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>`
  }

  _listSectionHTML(sectionIndex) {
    return `
      <div class="bg-[#2a3942] rounded-lg p-3 space-y-2" data-template-builder-target="listSection">
        <div class="flex items-center gap-2">
          <input type="text"
                 name="marketing_template[list_sections][${sectionIndex}][title]"
                 placeholder="Título da seção"
                 class="flex-1 bg-[#1f2c34] text-white placeholder-[#8696a0] rounded-lg px-3 py-1.5 text-sm outline-none border border-transparent focus:border-[#00a884]">
          <button type="button"
                  data-action="click->template-builder#removeListSection"
                  class="text-[#8696a0] hover:text-red-400 p-1 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <button type="button"
                data-action="click->template-builder#addListRow"
                data-section-index="${sectionIndex}"
                class="text-[#00a884] hover:text-[#02966f] text-xs flex items-center gap-1 ml-3 mt-1">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Adicionar opção
        </button>
      </div>`
  }

  _listRowHTML(sectionIndex, rowIndex) {
    return `
      <div class="flex gap-2 items-center pl-3">
        <input type="text"
               name="marketing_template[list_sections][${sectionIndex}][rows][${rowIndex}][id]"
               placeholder="ID" value="row_${rowIndex}"
               class="w-16 bg-[#1f2c34] text-white placeholder-[#8696a0] rounded-lg px-2 py-1.5 text-xs outline-none border border-transparent focus:border-[#00a884]">
        <input type="text"
               name="marketing_template[list_sections][${sectionIndex}][rows][${rowIndex}][title]"
               placeholder="Título da opção"
               class="flex-1 bg-[#1f2c34] text-white placeholder-[#8696a0] rounded-lg px-2 py-1.5 text-xs outline-none border border-transparent focus:border-[#00a884]">
        <input type="text"
               name="marketing_template[list_sections][${sectionIndex}][rows][${rowIndex}][desc]"
               placeholder="Descrição"
               class="flex-1 bg-[#1f2c34] text-white placeholder-[#8696a0] rounded-lg px-2 py-1.5 text-xs outline-none border border-transparent focus:border-[#00a884]">
      </div>`
  }

  _reindexButtons() {
    this.buttonRowTargets.forEach((row, i) => {
      row.querySelectorAll("input, select").forEach(el => {
        el.name = el.name.replace(/\[buttons\]\[\d+\]/, `[buttons][${i}]`)
      })
    })
    this._buttonCount = this.buttonRowTargets.length
  }
}
