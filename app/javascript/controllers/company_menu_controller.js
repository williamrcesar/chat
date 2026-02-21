import { Controller } from "@hotwired/stimulus"

// Manages the company department menu editor in /company/settings/edit
export default class extends Controller {
  static targets = [
    "greeting", "departments", "deptRow", "deptLabel", "deptRole", "deptId",
    "previewGreeting", "previewDepts"
  ]
  static values = { departments: Array }

  connect() {
    this._updatePreview()
  }

  addDepartment(e) {
    e.preventDefault()
    const index = this.deptRowTargets.length
    const id    = `dept_${Date.now()}`

    const html = `
      <div class="flex items-center gap-2 bg-[#2a3942] rounded-lg px-3 py-2"
           data-company-menu-target="deptRow">
        <div class="w-2 h-2 rounded-full bg-[#00a884] flex-shrink-0"></div>
        <input type="text"
               class="flex-1 bg-transparent text-white text-sm outline-none placeholder-[#8696a0]"
               placeholder="Ex: Suporte"
               data-company-menu-target="deptLabel"
               data-action="input->company-menu#updatePreview"
               value="">
        <span class="text-[#8696a0] text-xs">role_name:</span>
        <input type="text"
               class="w-28 bg-[#1a242a] text-[#d1d7db] text-xs rounded px-2 py-1 outline-none"
               placeholder="Ex: Suporte"
               data-company-menu-target="deptRole"
               value="">
        <input type="hidden"
               data-company-menu-target="deptId"
               value="${id}">
        <button type="button"
                data-action="click->company-menu#removeDepartment"
                class="text-[#8696a0] hover:text-red-400 transition-colors ml-1">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>`

    this.departmentsTarget.insertAdjacentHTML("beforeend", html)
    this._updatePreview()
  }

  removeDepartment(e) {
    e.preventDefault()
    const row = e.currentTarget.closest("[data-company-menu-target~='deptRow']")
    if (row) row.remove()
    this._updatePreview()
  }

  updatePreview() {
    this._updatePreview()
  }

  // Serialize the menu to JSON and put it in the hidden field before form submission
  serializeMenu(e) {
    const departments = this._collectDepartments()
    const menu = {
      greeting:    this.greetingTarget.value.trim(),
      departments: departments
    }
    document.getElementById("menu_json_field").value = JSON.stringify(menu)
  }

  _collectDepartments() {
    const rows = this.deptRowTargets
    return rows.map((row, i) => {
      const label    = row.querySelector("[data-company-menu-target~='deptLabel']")?.value?.trim() || ""
      const roleName = row.querySelector("[data-company-menu-target~='deptRole']")?.value?.trim()  || label
      const idField  = row.querySelector("[data-company-menu-target~='deptId']")?.value            || `dept_${i}`
      return { id: idField, label, role_name: roleName }
    }).filter(d => d.label)
  }

  _updatePreview() {
    if (this.hasPreviewGreetingTarget) {
      this.previewGreetingTarget.textContent = this.greetingTarget?.value || ""
    }

    if (this.hasPreviewDeptsTarget) {
      const depts = this._collectDepartments()
      this.previewDeptsTarget.innerHTML = depts.map(d =>
        `<button class="w-full text-left text-[#00a884] text-sm py-1.5 px-2 hover:bg-[#2a3942] rounded transition-colors">
           ${d.label}
         </button>`
      ).join("")
    }
  }
}
