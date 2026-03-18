import { Controller } from "@hotwired/stimulus"

/**
 * Voice recorder — WhatsApp-style
 *
 * States:
 *   idle    → mic button visible (send-text when field has text)
 *   holding → pressing mic: live waveform + slide-to-cancel + lock icon
 *   locked  → tapped quickly: keeps recording, shows stop button on mic
 *   review  → stopped: playback waveform, Play, 🗑 Discard, ✈ Send
 */
export default class extends Controller {
  static values  = { sendPath: String }
  static targets = [
    "micBtn",         // green mic button (idle)
    "sendBtn",        // green send-text button (idle, text present)
    "inputWrap",      // textarea wrapper
    "bar",            // recording bar (holding / locked)
    "recDot",         // pulsing red dot
    "timer",          // "0:12" elapsed
    "waveform",       // live waveform canvas
    "cancelHint",     // "← Deslize p/ cancelar"
    "lockBtn",        // 🔒 lock button (holding mode)
    "pauseBtn",       // ⏸/▶ pause/resume (locked mode)
    "reviewBar",      // review bar (after stop)
    "playbackWrap",   // seekable area
    "playbackCanvas", // static waveform canvas
    "playhead",       // position marker
    "durationLabel",  // total duration
    "playBtn",        // ▶/⏸ preview
    "cancelBtn",      // 🗑 discard
    "sendVoiceBtn",   // ✈ send
  ]

  connect() {
    this._state       = "idle"
    this._chunks      = []
    this._savedBlob   = null
    this._savedExt    = "webm"
    this._startX      = 0
    this._startTime   = 0
    this._elapsed     = 0
    this._paused      = false
    this._timerInt    = null
    this._waveInt     = null
    this._stream      = null
    this._analyser    = null
    this._audioCtx    = null
    this._mr          = null   // MediaRecorder
    this._audioEl     = null   // HTMLAudioElement for review
    this._playAnimId  = null
    this._peakData    = []

    this._boundMove = this._onPointerMove.bind(this)
    this._boundUp   = this._onPointerUp.bind(this)

    requestAnimationFrame(() => this._syncButtons())
  }

  disconnect() {
    this._abort()
    this._stopPreview()
  }

  // ─── Text field sync ────────────────────────────────────────────────────

  onInput(e) { this._syncButtons(e.target.value) }

  _syncButtons(value) {
    if (value === undefined) {
      const ta = this.hasInputWrapTarget ? this.inputWrapTarget.querySelector("textarea") : null
      value = ta ? ta.value : ""
    }
    const has = String(value).trim().length > 0
    if (this.hasSendBtnTarget) this.sendBtnTarget.style.display = has ? "" : "none"
    if (this.hasMicBtnTarget)  this.micBtnTarget.style.display  = has ? "none" : ""
  }

  // ─── Mic pointer ────────────────────────────────────────────────────────

  pointerDown(e) {
    if (this._state === "review") return
    if (this._state === "locked" || this._state === "holding") {
      this._stopRecording(); return
    }
    e.preventDefault()
    this._startX    = e.clientX ?? e.touches?.[0]?.clientX ?? 0
    this._startTime = Date.now()
    this._chunks    = []
    this._peakData  = []

    document.addEventListener("pointermove", this._boundMove, { passive: true })
    document.addEventListener("pointerup",   this._boundUp)

    this._beginRecording()
  }

  _onPointerMove(e) {
    if (this._state !== "holding") return
    const dx = this._startX - (e.clientX ?? 0)
    if (this.hasCancelHintTarget)
      this.cancelHintTarget.style.opacity = dx > 30 ? String(Math.min(1, (dx - 30) / 60)) : "0"
    if (dx > 130) {
      this._cancelRecording()
      document.removeEventListener("pointermove", this._boundMove)
      document.removeEventListener("pointerup",   this._boundUp)
    }
  }

  _onPointerUp() {
    document.removeEventListener("pointermove", this._boundMove)
    document.removeEventListener("pointerup",   this._boundUp)
    if (this._state !== "holding") return
    const held = Date.now() - this._startTime
    if (held < 400) {
      this._lockRecording()   // quick tap → keep recording, show stop on mic
    } else {
      this._stopRecording()   // held long enough → go to review
    }
  }

  // ─── Locked mode ────────────────────────────────────────────────────────

  togglePause() {
    if (this._state !== "locked") return
    this._paused ? this._resumeRecording() : this._pauseRecording()
  }

  // ─── Review mode ────────────────────────────────────────────────────────

  togglePlayback() {
    if (this._state !== "review" || !this._audioEl) return
    if (this._audioEl.paused) {
      this._audioEl.play().catch(err => console.warn("play error:", err))
      this._startPlayheadAnim()
      this._setPlayBtnIcon("pause")
    } else {
      this._audioEl.pause()
      cancelAnimationFrame(this._playAnimId)
      this._setPlayBtnIcon("play")
    }
  }

  seekPlayback(e) {
    if (this._state !== "review" || !this._audioEl) return
    const wrap = this.hasPlaybackWrapTarget ? this.playbackWrapTarget : null
    if (!wrap) return
    const r     = wrap.getBoundingClientRect()
    const ratio = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width))
    this._audioEl.currentTime = (this._audioEl.duration || 0) * ratio
    this._updatePlayhead()
    this._drawReviewWaveform(ratio) // redraw with highlight
  }

  cancelLocked() { this._cancelRecording() }

  sendLocked() {
    if (!this._savedBlob) {
      console.error("[VoiceRecorder] sendLocked: no blob saved")
      return
    }
    this._stopPreview()
    const blob = this._savedBlob
    const ext  = this._savedExt
    this._savedBlob = null
    this._state = "idle"
    this._hideAll()
    this._syncButtons()
    this._sendAudioBlob(blob, ext)
  }

  // ─── Recording internals ────────────────────────────────────────────────

  async _beginRecording() {
    try {
      this._stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (err) {
      console.warn("[VoiceRecorder] mic denied:", err)
      this._showError("Permissão de microfone negada")
      return
    }

    this._audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    const src = this._audioCtx.createMediaStreamSource(this._stream)
    this._analyser = this._audioCtx.createAnalyser()
    this._analyser.fftSize = 256
    src.connect(this._analyser)

    const mime = ["audio/webm;codecs=opus", "audio/webm", "audio/ogg;codecs=opus", "audio/mp4"]
      .find(t => MediaRecorder.isTypeSupported(t)) || ""

    this._mr = new MediaRecorder(this._stream, mime ? { mimeType: mime } : {})
    this._chunks = []
    this._mr.addEventListener("dataavailable", e => {
      if (e.data?.size > 0) this._chunks.push(e.data)
    })
    this._mr.start(100)

    this._state   = "holding"
    this._elapsed = 0
    this._paused  = false

    this._showHoldingUI()
    this._startTimer()
    this._startLiveWaveform()
  }

  _lockRecording() {
    this._state = "locked"
    this._showLockedUI()
  }

  _pauseRecording() {
    if (this._mr?.state === "recording") {
      this._mr.pause()
      this._paused = true
      clearInterval(this._waveInt)
      if (this.hasRecDotTarget) this.recDotTarget.style.animationPlayState = "paused"
      this._setPauseBtnIcon("resume")
    }
  }

  _resumeRecording() {
    if (this._mr?.state === "paused") {
      this._mr.resume()
      this._paused = false
      this._startLiveWaveform()
      if (this.hasRecDotTarget) this.recDotTarget.style.animationPlayState = "running"
      this._setPauseBtnIcon("pause")
    }
  }

  // Key fix: wait for all dataavailable events BEFORE building the blob
  async _stopRecording() {
    if (this._state !== "holding" && this._state !== "locked") return
    this._state = "review"
    this._stopTimers()

    // Flush & collect all chunks
    await new Promise(resolve => {
      if (!this._mr || this._mr.state === "inactive") { resolve(); return }
      this._mr.addEventListener("stop", resolve, { once: true })
      try { this._mr.stop() } catch (e) { console.warn(e); resolve() }
    })

    this._stopStream()

    const mime = this._mr?.mimeType || "audio/webm"
    const ext  = mime.includes("ogg") ? "ogg" : mime.includes("mp4") ? "mp4" : "webm"
    const blob = new Blob(this._chunks, { type: mime })

    console.log(`[VoiceRecorder] blob size: ${blob.size} bytes, type: ${mime}`)

    if (blob.size < 500) {
      this._state = "idle"
      this._hideAll()
      this._syncButtons()
      return
    }

    this._savedBlob = blob
    this._savedExt  = ext
    this._enterReview(blob)
  }

  _cancelRecording() {
    this._stopTimers()
    this._stopStream()
    this._stopPreview()
    if (this._mr && this._mr.state !== "inactive") {
      try { this._mr.stop() } catch {}
    }
    this._savedBlob = null
    this._state     = "idle"
    this._hideAll()
    this._syncButtons()
    if (this.hasMicBtnTarget) {
      this.micBtnTarget.style.background = "#ef4444"
      setTimeout(() => { if (this.hasMicBtnTarget) this.micBtnTarget.style.background = "" }, 500)
    }
  }

  _abort() {
    this._stopTimers()
    this._stopStream()
    document.removeEventListener("pointermove", this._boundMove)
    document.removeEventListener("pointerup",   this._boundUp)
    this._state = "idle"
  }

  // ─── Timer ──────────────────────────────────────────────────────────────

  _startTimer() {
    this._timerInt = setInterval(() => {
      if (this._paused) return
      this._elapsed++
      const m = Math.floor(this._elapsed / 60)
      const s = String(this._elapsed % 60).padStart(2, "0")
      if (this.hasTimerTarget) this.timerTarget.textContent = `${m}:${s}`
      if (this._elapsed >= 300) this._stopRecording()
    }, 1000)
  }

  _stopTimers() {
    clearInterval(this._timerInt); this._timerInt = null
    clearInterval(this._waveInt);  this._waveInt  = null
  }

  _stopStream() {
    this._stream?.getTracks().forEach(t => t.stop()); this._stream = null
    this._audioCtx?.close().catch(() => {}); this._audioCtx = null; this._analyser = null
  }

  // ─── Live waveform ───────────────────────────────────────────────────────

  _startLiveWaveform() {
    if (!this.hasWaveformTarget) return
    const canvas = this.waveformTarget
    const ctx    = canvas.getContext("2d")

    // Size canvas to match rendered width
    const parentW = canvas.parentElement?.getBoundingClientRect().width || 140
    const W = Math.floor(parentW)
    const H = 32
    canvas.width  = W
    canvas.height = H

    const BAR = 3, GAP = 2, N = Math.floor(W / (BAR + GAP))
    const hist = new Array(N).fill(0.05)
    let idx = 0

    clearInterval(this._waveInt)
    this._waveInt = setInterval(() => {
      if (!this._analyser) return
      const d = new Uint8Array(this._analyser.frequencyBinCount)
      this._analyser.getByteFrequencyData(d)
      const avg = d.reduce((a, b) => a + b, 0) / d.length
      const val = Math.max(0.04, Math.min(1, avg / 90))
      hist[idx % N] = val
      this._peakData.push(val)
      idx++

      ctx.clearRect(0, 0, W, H)
      for (let j = 0; j < N; j++) {
        const bh = Math.max(3, hist[j] * H)
        ctx.fillStyle = "#53bdeb"  // WhatsApp blue for recording waveform
        ctx.beginPath()
        ctx.roundRect(j * (BAR + GAP), (H - bh) / 2, BAR, bh, 1.5)
        ctx.fill()
      }
    }, 80)
  }

  // ─── Review ──────────────────────────────────────────────────────────────

  _enterReview(blob) {
    // Build audio element
    const url = URL.createObjectURL(blob)
    this._audioEl = new Audio(url)
    this._audioEl.preload = "metadata"

    this._audioEl.addEventListener("ended", () => {
      this._setPlayBtnIcon("play")
      cancelAnimationFrame(this._playAnimId)
      if (this.hasPlayheadTarget) this.playheadTarget.style.left = "0%"
      this._drawReviewWaveform(0)
    })

    const setDuration = () => {
      const d = this._audioEl.duration
      if (isFinite(d) && d > 0) {
        const m = Math.floor(d / 60)
        const s = String(Math.floor(d % 60)).padStart(2, "0")
        if (this.hasDurationLabelTarget) this.durationLabelTarget.textContent = `${m}:${s}`
      }
    }
    this._audioEl.addEventListener("loadedmetadata", setDuration)
    // Some browsers fire durationchange, not loadedmetadata
    this._audioEl.addEventListener("durationchange",  setDuration)

    // Show review bar, hide everything else
    if (this.hasBarTarget)        this.barTarget.style.display        = "none"
    if (this.hasInputWrapTarget)  this.inputWrapTarget.style.display   = "none"
    if (this.hasSendBtnTarget)    this.sendBtnTarget.style.display     = "none"
    if (this.hasMicBtnTarget)     this.micBtnTarget.style.display      = "none"

    if (this.hasReviewBarTarget) {
      this.reviewBarTarget.style.display    = "flex"
      this.reviewBarTarget.style.width      = "100%"
      this.reviewBarTarget.style.alignItems = "center"
    }
    // Send voice button is outside the pill — show it now
    if (this.hasSendVoiceBtnTarget) this.sendVoiceBtnTarget.style.display = ""

    this._setPlayBtnIcon("play")
    requestAnimationFrame(() => this._drawReviewWaveform(0))
  }

  _drawReviewWaveform(playRatio = 0) {
    if (!this.hasPlaybackCanvasTarget) return
    const canvas = this.playbackCanvasTarget
    const wrap   = this.hasPlaybackWrapTarget ? this.playbackWrapTarget : canvas.parentElement
    const W = Math.floor(wrap?.getBoundingClientRect().width || 180)
    const H = 32
    canvas.width  = W
    canvas.height = H
    const ctx = canvas.getContext("2d")

    const data = this._peakData.length > 0 ? this._peakData : new Array(60).fill(0.35)
    const BAR = 3, GAP = 2, N = Math.floor(W / (BAR + GAP))

    ctx.clearRect(0, 0, W, H)
    const playedX = playRatio * W

    for (let i = 0; i < N; i++) {
      const src = Math.floor((i / N) * data.length)
      const val = data[src] ?? 0.15
      const bh  = Math.max(3, val * H)
      const x   = i * (BAR + GAP)
      ctx.fillStyle = x < playedX ? "#00a884" : "rgba(134,150,160,0.55)"
      ctx.beginPath()
      ctx.roundRect(x, (H - bh) / 2, BAR, bh, 1.5)
      ctx.fill()
    }
  }

  _startPlayheadAnim() {
    const step = () => {
      this._updatePlayhead()
      if (this._audioEl && !this._audioEl.paused) {
        this._playAnimId = requestAnimationFrame(step)
      }
    }
    this._playAnimId = requestAnimationFrame(step)
  }

  _updatePlayhead() {
    if (!this._audioEl) return
    const { duration, currentTime } = this._audioEl
    if (!isFinite(duration) || duration === 0) return
    const ratio = currentTime / duration
    if (this.hasPlayheadTarget) this.playheadTarget.style.left = `${ratio * 100}%`
    this._drawReviewWaveform(ratio)
  }

  _stopPreview() {
    cancelAnimationFrame(this._playAnimId)
    if (this._audioEl) {
      this._audioEl.pause()
      URL.revokeObjectURL(this._audioEl.src)
      this._audioEl = null
    }
  }

  // ─── UI helpers ─────────────────────────────────────────────────────────

  _showHoldingUI() {
    if (this.hasInputWrapTarget) this.inputWrapTarget.style.display = "none"
    if (this.hasSendBtnTarget)   this.sendBtnTarget.style.display   = "none"
    if (this.hasReviewBarTarget) this.reviewBarTarget.style.display  = "none"

    if (this.hasBarTarget) {
      this.barTarget.style.display    = "flex"
      this.barTarget.style.width      = "100%"
      this.barTarget.style.alignItems = "center"
    }
    if (this.hasTimerTarget)      this.timerTarget.textContent = "0:00"
    if (this.hasCancelHintTarget) this.cancelHintTarget.style.opacity = "0"
    if (this.hasLockBtnTarget)    this.lockBtnTarget.style.display   = "flex"
    if (this.hasPauseBtnTarget)   this.pauseBtnTarget.style.display  = "none"
    if (this.hasRecDotTarget)     this.recDotTarget.style.animationPlayState = "running"

    if (this.hasMicBtnTarget) {
      this.micBtnTarget.style.background = "#ef4444"
      this.micBtnTarget.style.transform  = "scale(1.1)"
      this.micBtnTarget.title = "Toque para parar"
    }
  }

  _showLockedUI() {
    if (this.hasLockBtnTarget)  this.lockBtnTarget.style.display  = "none"
    if (this.hasPauseBtnTarget) { this.pauseBtnTarget.style.display = "flex"; this._setPauseBtnIcon("pause") }
    if (this.hasCancelHintTarget) this.cancelHintTarget.style.opacity = "0"
    if (this.hasMicBtnTarget) {
      this.micBtnTarget.style.background = "#ef4444"
      this.micBtnTarget.style.transform  = "scale(1.1)"
      this.micBtnTarget.title = "Toque para parar"
    }
  }

  _hideAll() {
    if (this.hasBarTarget)          this.barTarget.style.display          = "none"
    if (this.hasReviewBarTarget)    this.reviewBarTarget.style.display     = "none"
    if (this.hasSendVoiceBtnTarget) this.sendVoiceBtnTarget.style.display  = "none"
    if (this.hasInputWrapTarget)    this.inputWrapTarget.style.display     = ""
    if (this.hasMicBtnTarget) {
      this.micBtnTarget.style.background = ""
      this.micBtnTarget.style.transform  = ""
      this.micBtnTarget.title = "Segurar para gravar"
    }
  }

  _setPauseBtnIcon(mode) {
    if (!this.hasPauseBtnTarget) return
    const isPause = mode === "pause"
    this.pauseBtnTarget.innerHTML = isPause
      ? `<svg xmlns="http://www.w3.org/2000/svg" style="width:13px;height:13px;" fill="currentColor" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>`
      : `<svg xmlns="http://www.w3.org/2000/svg" style="width:13px;height:13px;" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`
    this.pauseBtnTarget.title = isPause ? "Pausar" : "Continuar gravação"
    this.pauseBtnTarget.style.background = isPause ? "#2a3942" : "#00a884"
  }

  _setPlayBtnIcon(mode) {
    if (!this.hasPlayBtnTarget) return
    const isPlay = mode === "play"
    this.playBtnTarget.innerHTML = isPlay
      ? `<svg xmlns="http://www.w3.org/2000/svg" style="width:14px;height:14px;" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`
      : `<svg xmlns="http://www.w3.org/2000/svg" style="width:13px;height:13px;" fill="currentColor" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16"/><rect x="14" y="4" width="4" height="16"/></svg>`
    this.playBtnTarget.title = isPlay ? "Ouvir gravação" : "Pausar"
  }

  // ─── Upload ──────────────────────────────────────────────────────────────

  _sendAudioBlob(blob, ext) {
    console.log(`[VoiceRecorder] sending blob: ${blob.size} bytes as voice.${ext}`)

    const messages = document.getElementById("messages")
    let ph = null
    if (messages) {
      ph = document.createElement("div")
      ph.style.cssText = "display:flex;justify-content:flex-end;padding:4px 8px;"
      ph.innerHTML = `
        <div style="background:#005c4b;border-radius:12px;padding:8px 14px;display:flex;align-items:center;gap:8px;max-width:260px;">
          <svg style="width:18px;height:18px;color:#8696a0;flex-shrink:0;animation:voiceSpin 1s linear infinite;" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle style="opacity:.25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path style="opacity:.75" fill="currentColor" d="M4 12a8 8 0 018-8v8z"/>
          </svg>
          <span style="color:#8696a0;font-size:13px;">Enviando áudio…</span>
        </div>`
      messages.appendChild(ph)
      ph.scrollIntoView({ behavior: "smooth", block: "end" })
    }

    if (!document.getElementById("voice-spin-kf")) {
      const s = document.createElement("style")
      s.id = "voice-spin-kf"
      s.textContent = "@keyframes voiceSpin{to{transform:rotate(360deg)}}"
      document.head.appendChild(s)
    }

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content || ""
    const fd   = new FormData()
    fd.append("audio", new File([blob], `voice.${ext}`, { type: blob.type }))

    fetch(this.sendPathValue, {
      method:  "POST",
      headers: { "X-CSRF-Token": csrf, "Accept": "text/vnd.turbo-stream.html" },
      body:    fd
    })
      .then(r => {
        if (!r.ok) { console.error("[VoiceRecorder] server error:", r.status, r.statusText); ph?.remove(); return }
        return r.text()
      })
      .then(html => {
        ph?.remove()
        if (html) Turbo.renderStreamMessage(html)
      })
      .catch(err => {
        console.error("[VoiceRecorder] fetch error:", err)
        ph?.remove()
      })
  }

  _showError(msg) {
    this._hideAll()
    const bar = this.hasBarTarget ? this.barTarget : null
    if (!bar) return
    bar.style.display = "flex"
    const prev = bar.innerHTML
    bar.innerHTML = `<span style="color:#f87171;font-size:12px;padding:0 12px;flex:1;">${msg}</span>`
    setTimeout(() => { bar.innerHTML = prev; bar.style.display = "none" }, 3000)
  }
}
