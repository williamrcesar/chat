import { Controller } from "@hotwired/stimulus"

// Manages the sticker/GIF bottom-sheet panel, the file editor modal,
// and sending stickers via AJAX.
export default class extends Controller {
  static values = {
    sendPath:     String,
    stickersPath: String,
    giphyKey:     String
  }
  static targets = ["uploadInput"]

  connect() {
    this._panelBound     = false
    this._cropperInst    = null
    this._editingBlob    = null
    this._eraserHistory  = []
    this._bgHistory      = []
    this._cropShape      = "free"
    this._boundOutside   = this._onDocClick.bind(this)
    requestAnimationFrame(() => this._bindPanelButtons())
  }

  disconnect() {
    this._closePanel()
    this._destroyCropper()
  }

  // ── Toggle ──────────────────────────────────────────────────────────────────

  toggle(event) {
    event.stopPropagation()
    const panel = document.getElementById("sticker-panel")
    if (!panel) return
    if (panel.style.display === "none" || !panel.style.display) {
      this._openPanel()
    } else {
      this._closePanel()
    }
  }

  _openPanel() {
    const panel   = document.getElementById("sticker-panel")
    const overlay = document.getElementById("sticker-overlay")
    if (!panel) return
    panel.style.display = "flex"
    if (overlay) {
      overlay.style.display = "block"
      overlay.style.pointerEvents = "auto"
    }
    this._loadMyStickers()
    requestAnimationFrame(() => {
      document.addEventListener("click", this._boundOutside)
    })
  }

  _closePanel() {
    const panel   = document.getElementById("sticker-panel")
    const overlay = document.getElementById("sticker-overlay")
    if (panel)   panel.style.display   = "none"
    if (overlay) {
      overlay.style.display = "none"
      overlay.style.pointerEvents = "none"
    }
    document.removeEventListener("click", this._boundOutside)
  }

  _onDocClick(event) {
    const panel = document.getElementById("sticker-panel")
    const modal = document.getElementById("sticker-crop-modal")
    if (!panel) return
    if (panel.style.display === "none") return
    if (panel.contains(event.target)) return
    if (this.element.contains(event.target)) return
    if (modal && modal.contains(event.target)) return
    this._closePanel()
  }

  // ── Panel button bindings ────────────────────────────────────────────────────

  _bindPanelButtons() {
    if (this._panelBound) return
    this._panelBound = true

    const get = id => document.getElementById(id)

    // Close button
    get("sp-close-btn")?.addEventListener("click", () => this._closePanel())

    // Import button → triggers file input
    get("sp-import-btn")?.addEventListener("click", () => {
      if (this.hasUploadInputTarget) this.uploadInputTarget.click()
    })

    // Tab switching
    get("sp-tab-my")?.addEventListener("click",      () => this._switchTab("my"))
    get("sp-tab-sticker")?.addEventListener("click", () => this._switchTab("sticker"))
    get("sp-tab-gif")?.addEventListener("click",     () => this._switchTab("gif"))

    // GIPHY search with debounce
    const stickerSearch = get("sp-sticker-search")
    if (stickerSearch) {
      stickerSearch.addEventListener("input", () => {
        clearTimeout(this._stickerDebounce)
        this._stickerDebounce = setTimeout(() => this._searchGiphyStickers(stickerSearch.value), 400)
      })
    }
    const gifSearch = get("sp-gif-search")
    if (gifSearch) {
      gifSearch.addEventListener("input", () => {
        clearTimeout(this._gifDebounce)
        this._gifDebounce = setTimeout(() => this._searchGiphyGifs(gifSearch.value), 400)
      })
    }

    // Editor modal buttons
    this._bindEditorButtons()
  }

  _switchTab(tab) {
    const tabs   = ["my", "sticker", "gif"]
    const panes  = { my: "sp-pane-my", sticker: "sp-pane-sticker", gif: "sp-pane-gif" }
    const btnIds = { my: "sp-tab-my",  sticker: "sp-tab-sticker",  gif: "sp-tab-gif" }

    tabs.forEach(t => {
      const pane = document.getElementById(panes[t])
      const btn  = document.getElementById(btnIds[t])
      if (pane) {
        pane.style.display         = t === tab ? "flex" : "none"
        pane.style.flexDirection   = "column"
      }
      if (btn) {
        btn.style.color       = t === tab ? "#fff"      : "#8696a0"
        btn.style.borderColor = t === tab ? "#00a884"   : "transparent"
        btn.style.borderBottomWidth = "2px"
        btn.style.borderBottomStyle = "solid"
      }
    })

    if (tab === "sticker" && !this._stickerLoaded) {
      this._stickerLoaded = true
      this._searchGiphyStickers("")
    }
    if (tab === "gif" && !this._gifLoaded) {
      this._gifLoaded = true
      this._searchGiphyGifs("")
    }
  }

  // ── My Stickers ─────────────────────────────────────────────────────────────

  _loadMyStickers() {
    if (!this.stickersPathValue) return
    const grid = document.getElementById("sp-grid")
    if (!grid) return
    fetch(this.stickersPathValue, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(stickers => this._renderMyGrid(stickers))
      .catch(() => { if (grid) grid.innerHTML = '<p style="color:#8696a0;font-size:12px;text-align:center;grid-column:1/-1;padding:32px 0;">Erro ao carregar figurinhas</p>' })
  }

  _renderMyGrid(stickers) {
    const grid = document.getElementById("sp-grid")
    if (!grid) return
    if (!stickers.length) {
      grid.innerHTML = '<p style="color:#8696a0;font-size:12px;text-align:center;grid-column:1/-1;padding:32px 0;">Nenhuma figurinha ainda.<br>Clique em + Importar para adicionar.</p>'
      return
    }
    grid.innerHTML = ""
    stickers.forEach(s => {
      const wrap = document.createElement("div")
      wrap.style.cssText = "position:relative;aspect-ratio:1;border-radius:12px;overflow:hidden;background:#0b141a;cursor:pointer;border:2px solid transparent;transition:border-color 0.15s;"

      const img = document.createElement("img")
      img.src = s.image_url
      img.alt = s.name || "Figurinha"
      img.style.cssText = "width:100%;height:100%;object-fit:contain;display:block;pointer-events:none;"
      img.loading = "lazy"

      // Small options button in top-right corner — always visible
      const menuBtn = document.createElement("button")
      menuBtn.type = "button"
      menuBtn.textContent = "⋮"
      menuBtn.title = "Opções"
      menuBtn.style.cssText = "position:absolute;top:3px;right:4px;background:rgba(0,0,0,0.6);color:white;border:none;border-radius:50%;width:22px;height:22px;font-size:13px;line-height:1;cursor:pointer;display:flex;align-items:center;justify-content:center;z-index:2;padding:0;"

      // Dropdown actions
      const dropdown = document.createElement("div")
      dropdown.style.cssText = "display:none;position:absolute;top:28px;right:4px;background:#2a3942;border-radius:8px;box-shadow:0 4px 16px rgba(0,0,0,0.5);z-index:10;min-width:110px;overflow:hidden;"

      const editItem = document.createElement("button")
      editItem.type = "button"
      editItem.textContent = "✏️ Editar"
      editItem.style.cssText = "display:block;width:100%;text-align:left;background:none;color:white;border:none;padding:8px 12px;font-size:12px;cursor:pointer;"
      editItem.addEventListener("mouseenter", () => { editItem.style.background = "#3d4a52" })
      editItem.addEventListener("mouseleave", () => { editItem.style.background = "none" })

      const delItem = document.createElement("button")
      delItem.type = "button"
      delItem.textContent = "🗑️ Apagar"
      delItem.style.cssText = "display:block;width:100%;text-align:left;background:none;color:#f87171;border:none;padding:8px 12px;font-size:12px;cursor:pointer;"
      delItem.addEventListener("mouseenter", () => { delItem.style.background = "#3d4a52" })
      delItem.addEventListener("mouseleave", () => { delItem.style.background = "none" })

      dropdown.appendChild(editItem)
      dropdown.appendChild(delItem)
      wrap.appendChild(img)
      wrap.appendChild(menuBtn)
      wrap.appendChild(dropdown)
      grid.appendChild(wrap)

      // Hover highlight
      wrap.addEventListener("mouseenter", () => { wrap.style.borderColor = "#00a884" })
      wrap.addEventListener("mouseleave", () => { wrap.style.borderColor = "transparent"; dropdown.style.display = "none" })

      // Toggle dropdown
      menuBtn.addEventListener("click", (e) => {
        e.stopPropagation()
        dropdown.style.display = dropdown.style.display === "none" ? "block" : "none"
      })

      // Click on wrap = send sticker (unless dropdown is open)
      wrap.addEventListener("click", (e) => {
        if (dropdown.style.display === "block") { dropdown.style.display = "none"; return }
        if (e.target === menuBtn) return
        this._sendStickerById(s.id)
      })

      // Edit
      editItem.addEventListener("click", (e) => {
        e.stopPropagation()
        dropdown.style.display = "none"
        this._openEditorFromUrl(s.image_url, s.id)
      })

      // Delete
      delItem.addEventListener("click", (e) => {
        e.stopPropagation()
        dropdown.style.display = "none"
        if (!confirm("Apagar esta figurinha?")) return
        const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
        fetch(`/stickers/${s.id}`, {
          method: "DELETE",
          headers: { "X-CSRF-Token": csrfToken }
        }).then(() => { wrap.remove() })
      })

      // Close dropdown when clicking outside
      document.addEventListener("click", () => { dropdown.style.display = "none" }, { once: false })
    })

    // Close all dropdowns on outside click
    grid.addEventListener("click", (e) => {
      grid.querySelectorAll("[data-dropdown]").forEach(d => d.style.display = "none")
    })
  }

  _sendStickerById(id) {
    this._closePanel()
    const placeholder = this._showSendingPlaceholder()
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    fetch(this.sendPathValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken, "Accept": "text/vnd.turbo-stream.html" },
      body: JSON.stringify({ sticker_id: id })
    }).then(r => r.text()).then(html => {
      placeholder?.remove()
      if (html) Turbo.renderStreamMessage(html)
    }).catch(() => { placeholder?.remove() })
  }

  // ── File input ───────────────────────────────────────────────────────────────

  onFileSelect(event) {
    const files = Array.from(event.target.files || [])
    if (!files.length) return
    if (files.length === 1) {
      this._openEditorFromFile(files[0])
    } else {
      this._bulkUpload(files)
    }
    event.target.value = ""
  }

  _bulkUpload(files) {
    const progress  = document.getElementById("sp-progress")
    const bar       = document.getElementById("sp-progress-bar")
    const label     = document.getElementById("sp-progress-label")
    const count     = document.getElementById("sp-progress-count")
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    let done = 0
    if (progress) progress.style.display = "block"

    const next = () => {
      if (done >= files.length) {
        if (progress) progress.style.display = "none"
        this._loadMyStickers()
        return
      }
      const file = files[done]
      if (label)  label.textContent  = `Importando ${file.name}…`
      if (count)  count.textContent  = `${done + 1}/${files.length}`
      if (bar)    bar.style.width    = `${Math.round((done / files.length) * 100)}%`

      const fd = new FormData()
      fd.append("sticker[image]", file)
      fetch("/stickers", {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken },
        body: fd
      }).finally(() => { done++; next() })
    }
    next()
  }

  // ── GIPHY ────────────────────────────────────────────────────────────────────

  _searchGiphyStickers(query) {
    const key = this.giphyKeyValue
    if (!key) { this._showGiphyKeyError("sp-sticker-grid"); return }
    const url = query
      ? `https://api.giphy.com/v1/stickers/search?api_key=${key}&q=${encodeURIComponent(query)}&limit=24&rating=g`
      : `https://api.giphy.com/v1/stickers/trending?api_key=${key}&limit=24&rating=g`
    fetch(url)
      .then(r => r.json())
      .then(json => this._renderGiphyGrid("sp-sticker-grid", json.data, true))
      .catch(() => this._showGiphyKeyError("sp-sticker-grid"))
  }

  _searchGiphyGifs(query) {
    const key = this.giphyKeyValue
    if (!key) { this._showGiphyKeyError("sp-gif-grid"); return }
    const url = query
      ? `https://api.giphy.com/v1/gifs/search?api_key=${key}&q=${encodeURIComponent(query)}&limit=20&rating=g`
      : `https://api.giphy.com/v1/gifs/trending?api_key=${key}&limit=20&rating=g`
    fetch(url)
      .then(r => r.json())
      .then(json => this._renderGiphyGrid("sp-gif-grid", json.data, false))
      .catch(() => this._showGiphyKeyError("sp-gif-grid"))
  }

  _renderGiphyGrid(gridId, items, isSticker) {
    const grid = document.getElementById(gridId)
    if (!grid) return
    if (!items || !items.length) {
      grid.innerHTML = '<p style="color:#8696a0;font-size:12px;text-align:center;grid-column:1/-1;padding:32px 0;">Nenhum resultado</p>'
      return
    }
    grid.innerHTML = ""
    items.forEach(item => {
      const src = item.images?.fixed_width_small?.url || item.images?.fixed_height?.url || item.images?.downsized?.url || ""
      if (!src) return
      const img = document.createElement("img")
      img.src   = src
      img.loading = "lazy"
      img.style.cssText = "width:100%;height:auto;display:block;border-radius:8px;cursor:pointer;transition:opacity 0.15s;"
      img.addEventListener("mouseenter", () => { img.style.opacity = "0.75" })
      img.addEventListener("mouseleave", () => { img.style.opacity = "1" })
      img.addEventListener("click", (e) => {
        e.stopPropagation()
        const gifUrl = item.images?.original?.url || item.images?.downsized?.url || src
        this._sendGiphyGif(gifUrl)
      })
      grid.appendChild(img)
    })
  }

  _sendGiphyGif(gifUrl) {
    this._closePanel()
    const placeholder = this._showSendingPlaceholder()
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    fetch(gifUrl).then(r => r.blob()).then(blob => {
      const file = new File([blob], "giphy.gif", { type: "image/gif" })
      const fd   = new FormData()
      fd.append("sticker_file", file)
      return fetch(this.sendPathValue, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken, "Accept": "text/vnd.turbo-stream.html" },
        body: fd
      })
    }).then(r => r.text()).then(html => {
      placeholder?.remove()
      if (html) Turbo.renderStreamMessage(html)
    }).catch(() => { placeholder?.remove() })
  }

  // Shows a temporary "sending" bubble in the messages list.
  // Returns the element so the caller can remove it when the real message arrives.
  _showSendingPlaceholder() {
    const messages = document.getElementById("messages")
    if (!messages) return null

    const el = document.createElement("div")
    el.id = "sticker-sending-placeholder"
    el.style.cssText = "display:flex;justify-content:flex-end;padding:4px 8px;"
    el.innerHTML = `
      <div style="display:flex;flex-direction:column;align-items:flex-end;max-width:min(65%,22rem);">
        <div style="background:#005c4b;border-radius:12px;padding:10px 14px;display:flex;align-items:center;gap:8px;">
          <svg style="width:20px;height:20px;color:#8696a0;animation:spin 1s linear infinite;flex-shrink:0;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle style="opacity:0.25;" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path style="opacity:0.75;" fill="currentColor" d="M4 12a8 8 0 018-8v8z"></path>
          </svg>
          <span style="color:#8696a0;font-size:13px;">Enviando…</span>
        </div>
      </div>
    `
    messages.appendChild(el)
    el.scrollIntoView({ behavior: "smooth", block: "end" })

    // Inject spin keyframes once
    if (!document.getElementById("sticker-spin-style")) {
      const style = document.createElement("style")
      style.id = "sticker-spin-style"
      style.textContent = "@keyframes spin { to { transform: rotate(360deg); } }"
      document.head.appendChild(style)
    }

    return el
  }

  _showGiphyKeyError(gridId) {
    const grid = document.getElementById(gridId)
    if (grid) grid.innerHTML = '<p style="color:#8696a0;font-size:12px;text-align:center;grid-column:1/-1;padding:32px 0;">Configure GIPHY_API_KEY no .env</p>'
  }

  // ── Image Editor ─────────────────────────────────────────────────────────────

  _openEditorFromFile(file) {
    this._closePanel()
    const reader = new FileReader()
    reader.onload = (e) => this._openEditorWithDataUrl(e.target.result, null)
    reader.readAsDataURL(file)
  }

  _openEditorFromUrl(url, stickerId) {
    this._closePanel()
    fetch(url)
      .then(r => r.blob())
      .then(blob => {
        const reader = new FileReader()
        reader.onload = (e) => this._openEditorWithDataUrl(e.target.result, stickerId)
        reader.readAsDataURL(blob)
      })
  }

  _openEditorWithDataUrl(dataUrl, stickerId) {
    this._currentEditStickerId = stickerId
    const modal = document.getElementById("sticker-crop-modal")
    if (!modal) return
    modal.style.display = "flex"

    // Reset shape to "free" every time editor opens
    this._cropShape   = "free"
    this._cropperPending = true   // flag: onload will init cropper
    this._destroyCropper()

    // Load canvas tools (eraser / bg-remove panels)
    this._loadCanvasImage(dataUrl)

    // Switch to crop tab (must happen before image src is set so the pane is visible)
    this._switchEditorTab("crop")

    // Load image into crop tool — init Cropper after image loads
    const cropImg = document.getElementById("sticker-crop-img")
    if (cropImg) {
      cropImg.onload = () => {
        this._cropperPending = false
        this._initCropper()
      }
      cropImg.src           = dataUrl
      cropImg.style.display = "block"
      // If already loaded from cache, fire onload manually
      if (cropImg.complete && cropImg.naturalWidth > 0) {
        cropImg.onload()
      }
    }
  }

  _loadCanvasImage(dataUrl) {
    this._canvasDataUrl = dataUrl
    const img = new Image()
    img.onload = () => {
      this._canvasSourceImg = img
      this._initEraserCanvas(img)
      this._initBgCanvas(img)
    }
    img.src = dataUrl
  }

  _bindEditorButtons() {
    const get = id => document.getElementById(id)

    // Editor tabs
    get("editor-tab-crop")?.addEventListener("click",  () => this._switchEditorTab("crop"))
    get("editor-tab-erase")?.addEventListener("click", () => this._switchEditorTab("erase"))
    get("editor-tab-bg")?.addEventListener("click",    () => this._switchEditorTab("bg"))

    // Close
    get("sticker-crop-close")?.addEventListener("click", () => this._closeEditor())

    // Crop shape buttons
    get("crop-shape-free")?.addEventListener("click",   () => this._setCropShape("free"))
    get("crop-shape-square")?.addEventListener("click", () => this._setCropShape("square"))
    get("crop-shape-circle")?.addEventListener("click", () => this._setCropShape("circle"))

    // Crop save/send
    get("sticker-crop-reset")?.addEventListener("click", () => this._resetCrop())
    get("sticker-crop-save")?.addEventListener("click",  () => this._saveCrop(false))
    get("sticker-crop-send")?.addEventListener("click",  () => this._saveCrop(true))

    // Eraser toolbar
    const eraserSize = get("eraser-size")
    if (eraserSize) {
      eraserSize.addEventListener("input", () => {
        const label = get("eraser-size-label")
        if (label) label.textContent = eraserSize.value
      })
    }
    get("eraser-undo")?.addEventListener("click",  () => this._eraserUndo())
    get("eraser-clear")?.addEventListener("click", () => { if (this._canvasSourceImg) this._initEraserCanvas(this._canvasSourceImg) })
    get("eraser-save")?.addEventListener("click",  () => this._saveEraser(false))
    get("eraser-send")?.addEventListener("click",  () => this._saveEraser(true))

    // BG remove toolbar
    const bgTol = get("bg-tolerance")
    if (bgTol) {
      bgTol.addEventListener("input", () => {
        const label = get("bg-tolerance-label")
        if (label) label.textContent = bgTol.value
      })
    }
    get("bg-undo")?.addEventListener("click",  () => this._bgUndo())
    get("bg-save")?.addEventListener("click",  () => this._saveBg(false))
    get("bg-send")?.addEventListener("click",  () => this._saveBg(true))
  }

  _switchEditorTab(tab) {
    const panes = { crop: "editor-pane-crop", erase: "editor-pane-erase", bg: "editor-pane-bg" }
    const btns  = { crop: "editor-tab-crop",  erase: "editor-tab-erase",  bg: "editor-tab-bg" }
    Object.keys(panes).forEach(t => {
      const pane = document.getElementById(panes[t])
      const btn  = document.getElementById(btns[t])
      const active = t === tab
      if (pane) {
        pane.style.display       = active ? "flex" : "none"
        pane.style.flexDirection = "column"
        pane.style.flex          = "1"
        pane.style.minHeight     = "0"
        pane.style.overflow      = "hidden"
      }
      if (btn) {
        btn.style.color              = active ? "#fff"      : "#8696a0"
        btn.style.borderBottomColor  = active ? "#00a884"   : "transparent"
        btn.style.borderBottomWidth  = "2px"
        btn.style.borderBottomStyle  = "solid"
      }
    })
    if (tab === "crop") {
      // Only init if not already initialized and no pending init from onload
      if (!this._cropperInst && !this._cropperPending) {
        requestAnimationFrame(() => this._initCropper())
      }
    } else {
      this._destroyCropper()
    }
  }

  _closeEditor() {
    const modal = document.getElementById("sticker-crop-modal")
    if (modal) { modal.style.display = "none" }
    this._destroyCropper()
  }

  // ── Crop tool (Cropper.js) ──────────────────────────────────────────────

  _initCropper() {
    const img = document.getElementById("sticker-crop-img")
    if (!img || !img.src || img.src === window.location.href) return
    // Cropper needs the image to be visible
    img.style.display = "block"
    this._destroyCropper()
    if (typeof Cropper === "undefined") return

    this._cropperInst = new Cropper(img, {
      viewMode:     2,
      autoCropArea: 0.85,
      background:   false,
      movable:      true,
      zoomable:     true,
      scalable:     false,
      rotatable:    false,
      aspectRatio:  NaN,
      ready: () => {
        this._setCropShape(this._cropShape || "free")
      }
    })
  }

  _destroyCropper() {
    if (this._cropperInst) { this._cropperInst.destroy(); this._cropperInst = null }
  }

  // Find the Cropper.js crop-box elements — container is a sibling of img, not a parent
  _getCropperEls() {
    const wrap = document.getElementById("sticker-crop-img-wrap")
    if (!wrap) return {}
    return {
      viewBox:   wrap.querySelector(".cropper-view-box"),
      face:      wrap.querySelector(".cropper-face"),
      cropBox:   wrap.querySelector(".cropper-crop-box"),
      container: wrap.querySelector(".cropper-container"),
    }
  }

  _setCropShape(shape) {
    // 1. Update button styles
    const btnIds = { free: "crop-shape-free", square: "crop-shape-square", circle: "crop-shape-circle" }
    Object.keys(btnIds).forEach(k => {
      const btn = document.getElementById(btnIds[k])
      if (!btn) return
      const active = k === shape
      btn.style.background  = active ? "#00a884" : "#2a3942"
      btn.style.color       = active ? "#fff"    : "#8696a0"
      btn.style.border      = active ? "1px solid #00a884" : "1px solid transparent"
    })

    this._cropShape = shape

    if (!this._cropperInst) return

    // 2. Set aspect ratio
    if (shape === "square" || shape === "circle") {
      this._cropperInst.setAspectRatio(1)
    } else {
      this._cropperInst.setAspectRatio(NaN)
    }

    // 3. Apply circular overlay — rAF ensures the crop-box DOM has been updated
    requestAnimationFrame(() => {
      const { viewBox, face } = this._getCropperEls()
      const radius = shape === "circle" ? "50%" : "0"
      if (viewBox) viewBox.style.borderRadius = radius
      if (face)    face.style.borderRadius    = radius
      // Also clip the inner image preview inside view-box
      const vbImg = viewBox?.querySelector("img")
      if (vbImg) vbImg.style.borderRadius = radius
    })
  }

  _resetCrop() { this._cropperInst?.reset() }

  _saveCrop(andSend) {
    if (!this._cropperInst) return
    const canvas = this._cropShape === "circle"
      ? this._circleCanvas(this._cropperInst.getCroppedCanvas({ width: 512, height: 512 }))
      : this._cropperInst.getCroppedCanvas({ width: 512, height: 512 })
    canvas.toBlob(blob => {
      if (andSend) {
        this._uploadAndSend(blob, "png")
      } else {
        this._uploadOnly(blob, "png")
      }
    }, "image/png")
    this._closeEditor()
  }

  _circleCanvas(src) {
    const c = document.createElement("canvas")
    c.width = src.width; c.height = src.height
    const ctx = c.getContext("2d")
    ctx.beginPath()
    ctx.arc(c.width / 2, c.height / 2, Math.min(c.width, c.height) / 2, 0, Math.PI * 2)
    ctx.clip()
    ctx.drawImage(src, 0, 0)
    return c
  }

  // Eraser tool
  _initEraserCanvas(img) {
    const canvas = document.getElementById("eraser-canvas")
    if (!canvas) return
    const maxW = canvas.parentElement?.clientWidth  || 400
    const maxH = canvas.parentElement?.clientHeight || 280
    const scale = Math.min(maxW / img.naturalWidth, maxH / img.naturalHeight, 1)
    canvas.width  = img.naturalWidth
    canvas.height = img.naturalHeight
    canvas.style.width  = `${Math.floor(img.naturalWidth  * scale)}px`
    canvas.style.height = `${Math.floor(img.naturalHeight * scale)}px`
    const ctx = canvas.getContext("2d")
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    ctx.drawImage(img, 0, 0)
    this._eraserHistory = [ctx.getImageData(0, 0, canvas.width, canvas.height)]
    this._bindEraserCanvas(canvas)
  }

  _bindEraserCanvas(canvas) {
    if (canvas._eraserBound) return
    canvas._eraserBound = true
    const cursor = document.getElementById("eraser-cursor")
    let drawing = false

    const getPos = (e) => {
      const rect  = canvas.getBoundingClientRect()
      const scaleX = canvas.width  / rect.width
      const scaleY = canvas.height / rect.height
      const cl = e.touches ? e.touches[0] : e
      return {
        x: (cl.clientX - rect.left) * scaleX,
        y: (cl.clientY - rect.top)  * scaleY,
        cx: cl.clientX, cy: cl.clientY
      }
    }

    const erase = (e) => {
      if (!drawing) return
      e.preventDefault()
      const { x, y } = getPos(e)
      const ctx  = canvas.getContext("2d")
      const size = parseInt(document.getElementById("eraser-size")?.value || "20")
      ctx.globalCompositeOperation = "destination-out"
      ctx.beginPath()
      ctx.arc(x, y, size / 2, 0, Math.PI * 2)
      ctx.fill()
    }

    canvas.addEventListener("mousedown",  (e) => { drawing = true; erase(e) })
    canvas.addEventListener("mousemove",  (e) => {
      erase(e)
      if (cursor) {
        const size = parseInt(document.getElementById("eraser-size")?.value || "20")
        cursor.style.width  = `${size}px`
        cursor.style.height = `${size}px`
        cursor.style.left   = `${e.clientX}px`
        cursor.style.top    = `${e.clientY}px`
        cursor.style.display = "block"
      }
    })
    canvas.addEventListener("mouseleave", () => { if (cursor) cursor.style.display = "none" })
    canvas.addEventListener("mouseup",    () => {
      if (drawing) {
        drawing = false
        const ctx = canvas.getContext("2d")
        this._eraserHistory.push(ctx.getImageData(0, 0, canvas.width, canvas.height))
      }
    })
    canvas.addEventListener("touchstart", (e) => { drawing = true; erase(e) }, { passive: false })
    canvas.addEventListener("touchmove",  erase, { passive: false })
    canvas.addEventListener("touchend",   () => { drawing = false })
  }

  _eraserUndo() {
    if (this._eraserHistory.length <= 1) return
    this._eraserHistory.pop()
    const canvas = document.getElementById("eraser-canvas")
    if (!canvas) return
    canvas.getContext("2d").putImageData(this._eraserHistory[this._eraserHistory.length - 1], 0, 0)
  }

  _saveEraser(andSend) {
    const canvas = document.getElementById("eraser-canvas")
    if (!canvas) return
    canvas.toBlob(blob => {
      if (andSend) this._uploadAndSend(blob, "png")
      else         this._uploadOnly(blob, "png")
    }, "image/png")
    this._closeEditor()
  }

  // BG remove tool (flood-fill)
  _initBgCanvas(img) {
    const canvas = document.getElementById("bg-canvas")
    if (!canvas) return
    const maxW = canvas.parentElement?.clientWidth  || 400
    const maxH = canvas.parentElement?.clientHeight || 280
    const scale = Math.min(maxW / img.naturalWidth, maxH / img.naturalHeight, 1)
    canvas.width  = img.naturalWidth
    canvas.height = img.naturalHeight
    canvas.style.width  = `${Math.floor(img.naturalWidth  * scale)}px`
    canvas.style.height = `${Math.floor(img.naturalHeight * scale)}px`
    const ctx = canvas.getContext("2d")
    ctx.drawImage(img, 0, 0)
    this._bgHistory = [ctx.getImageData(0, 0, canvas.width, canvas.height)]

    if (!canvas._bgBound) {
      canvas._bgBound = true
      canvas.addEventListener("click", (e) => {
        const rect = canvas.getBoundingClientRect()
        const scaleX = canvas.width  / rect.width
        const scaleY = canvas.height / rect.height
        const x = Math.floor((e.clientX - rect.left) * scaleX)
        const y = Math.floor((e.clientY - rect.top)  * scaleY)
        const tol = parseInt(document.getElementById("bg-tolerance")?.value || "30")
        this._floodFill(canvas, x, y, tol)
      })
    }
  }

  _floodFill(canvas, sx, sy, tolerance) {
    const ctx  = canvas.getContext("2d")
    const data = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const px   = data.data
    const w    = canvas.width
    const h    = canvas.height
    const idx  = (x, y) => (y * w + x) * 4
    const base = idx(sx, sy)
    const sr   = px[base], sg = px[base + 1], sb = px[base + 2], sa = px[base + 3]
    if (sa === 0) return

    const diff = (i) => Math.abs(px[i] - sr) + Math.abs(px[i + 1] - sg) + Math.abs(px[i + 2] - sb) + Math.abs(px[i + 3] - sa)
    const threshold = tolerance * 4

    const visited = new Uint8Array(w * h)
    const queue   = [sx + sy * w]
    visited[sx + sy * w] = 1

    while (queue.length) {
      const pos = queue.pop()
      const x   = pos % w
      const y   = Math.floor(pos / w)
      const i   = pos * 4
      if (diff(i) > threshold) continue
      px[i + 3] = 0

      const neighbors = [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]
      for (const [nx, ny] of neighbors) {
        if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
          const ni = nx + ny * w
          if (!visited[ni]) { visited[ni] = 1; queue.push(ni) }
        }
      }
    }
    this._bgHistory.push(data)
    ctx.putImageData(data, 0, 0)
  }

  _bgUndo() {
    if (this._bgHistory.length <= 1) return
    this._bgHistory.pop()
    const canvas = document.getElementById("bg-canvas")
    if (!canvas) return
    canvas.getContext("2d").putImageData(this._bgHistory[this._bgHistory.length - 1], 0, 0)
  }

  _saveBg(andSend) {
    const canvas = document.getElementById("bg-canvas")
    if (!canvas) return
    canvas.toBlob(blob => {
      if (andSend) this._uploadAndSend(blob, "png")
      else         this._uploadOnly(blob, "png")
    }, "image/png")
    this._closeEditor()
  }

  // ── Upload helpers ───────────────────────────────────────────────────────────

  _uploadOnly(blob, ext) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    const id = this._currentEditStickerId
    const fd = new FormData()
    fd.append("sticker[image]", new File([blob], `sticker.${ext}`, { type: `image/${ext}` }))
    const url    = id ? `/stickers/${id}` : "/stickers"
    const method = id ? "PATCH" : "POST"
    fetch(url, { method, headers: { "X-CSRF-Token": csrfToken }, body: fd })
      .then(() => this._loadMyStickers())
  }

  _uploadAndSend(blob, ext) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    const id = this._currentEditStickerId
    const fd = new FormData()
    fd.append("sticker[image]", new File([blob], `sticker.${ext}`, { type: `image/${ext}` }))
    const saveUrl    = id ? `/stickers/${id}` : "/stickers"
    const saveMethod = id ? "PATCH" : "POST"

    // First save the sticker, then send it
    fetch(saveUrl, { method: saveMethod, headers: { "X-CSRF-Token": csrfToken }, body: fd })
      .then(r => r.json())
      .then(s => {
        this._loadMyStickers()
        if (s.id) this._sendStickerById(s.id)
      })
      .catch(() => {
        // Fallback: send blob directly
        const placeholder = this._showSendingPlaceholder()
        const sendFd = new FormData()
        sendFd.append("sticker_file", new File([blob], `sticker.${ext}`, { type: `image/${ext}` }))
        fetch(this.sendPathValue, {
          method: "POST",
          headers: { "X-CSRF-Token": csrfToken, "Accept": "text/vnd.turbo-stream.html" },
          body: sendFd
        }).then(r => r.text()).then(html => {
          placeholder?.remove()
          if (html) Turbo.renderStreamMessage(html)
        }).catch(() => { placeholder?.remove() })
      })
  }
}
