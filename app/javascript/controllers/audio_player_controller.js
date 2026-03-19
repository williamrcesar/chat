import { Controller } from "@hotwired/stimulus"

/**
 * audio-player — WhatsApp-style inline audio player
 * Features: play/pause, seek, waveform visualization, speed control
 */
export default class extends Controller {
  static values  = { src: String }
  static targets = [
    "audio",      // hidden <audio> element
    "playBtn",    // play/pause button
    "playIcon",   // ▶ svg
    "pauseIcon",  // ⏸ svg
    "seekBar",    // clickable seek area
    "waveCanvas", // waveform canvas
    "playhead",   // position marker
    "timeLabel",  // current / duration text
    "speedBtn",   // speed label button
  ]

  static SPEEDS = [1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 3.5]

  connect() {
    this._speedIdx  = 0
    this._animId    = null
    this._drawn     = false

    const audio = this.hasAudioTarget ? this.audioTarget : null
    if (!audio) return

    audio.addEventListener("loadedmetadata", () => this._onMeta())
    audio.addEventListener("timeupdate",     () => this._onTick())
    audio.addEventListener("ended",          () => this._onEnded())
    audio.addEventListener("error",          () => this._onError())

    // Draw static waveform after a frame (canvas needs dimensions)
    requestAnimationFrame(() => this._drawWave(0))
  }

  disconnect() {
    cancelAnimationFrame(this._animId)
    if (this.hasAudioTarget) this.audioTarget.pause()
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  togglePlay() {
    const a = this.audioTarget
    if (a.paused) {
      // Pause all other players on the page first
      document.querySelectorAll("audio").forEach(el => {
        if (el !== a) el.pause()
      })
      a.play().catch(() => {})
      this._showPause()
      this._startAnim()
    } else {
      a.pause()
      this._showPlay()
      cancelAnimationFrame(this._animId)
    }
  }

  seek(event) {
    const a = this.audioTarget
    if (!isFinite(a.duration)) return
    const bar  = this.seekBarTarget
    const rect = bar.getBoundingClientRect()
    const ratio = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    a.currentTime = a.duration * ratio
    this._drawWave(ratio)
    this._updatePlayhead(ratio)
    this._updateTime()
  }

  cycleSpeed() {
    this._speedIdx = (this._speedIdx + 1) % this.constructor.SPEEDS.length
    const spd = this.constructor.SPEEDS[this._speedIdx]
    this.audioTarget.playbackRate = spd
    if (this.hasSpeedBtnTarget) {
      this.speedBtnTarget.textContent = spd === 1 ? "1×" : `${spd}×`
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  _onMeta() {
    this._updateTime()
    this._drawWave(0)
  }

  _onTick() {
    this._updateTime()
    const a = this.audioTarget
    if (!isFinite(a.duration) || a.duration === 0) return
    const ratio = a.currentTime / a.duration
    this._updatePlayhead(ratio)
    this._drawWave(ratio)
  }

  _onEnded() {
    this._showPlay()
    cancelAnimationFrame(this._animId)
    this._updatePlayhead(0)
    this._drawWave(0)
    if (this.hasAudioTarget) this.audioTarget.currentTime = 0
    this._updateTime()
  }

  _onError() {
    if (this.hasTimeLabelTarget) this.timeLabelTarget.textContent = "–"
  }

  _updateTime() {
    if (!this.hasTimeLabelTarget || !this.hasAudioTarget) return
    const a = this.audioTarget
    const t = isFinite(a.duration) ? a.duration : 0
    const c = a.currentTime || 0
    const fmt = s => `${Math.floor(s/60)}:${String(Math.floor(s%60)).padStart(2,"0")}`
    this.timeLabelTarget.textContent = a.paused && c === 0 ? fmt(t) : fmt(c)
  }

  _updatePlayhead(ratio) {
    if (!this.hasPlayheadTarget) return
    this.playheadTarget.style.left = `${(ratio || 0) * 100}%`
  }

  _drawWave(playedRatio = 0) {
    if (!this.hasWaveCanvasTarget) return
    const canvas = this.waveCanvasTarget
    const parent = this.hasSeekBarTarget ? this.seekBarTarget : canvas.parentElement
    const W = Math.floor(parent.getBoundingClientRect().width || 120)
    const H = 28
    if (W < 4) return
    canvas.width  = W
    canvas.height = H
    const ctx = canvas.getContext("2d")

    // Generate a deterministic pseudo-random waveform seeded by src
    if (!this._waveData || this._waveData.length === 0) {
      const seed = (this.srcValue || "").split("").reduce((a, c) => a + c.charCodeAt(0), 0) || 42
      const N = 60
      this._waveData = Array.from({ length: N }, (_, i) => {
        const x = Math.sin(seed * 0.1 + i * 0.7) * Math.cos(i * 0.4 + seed * 0.05)
        return Math.max(0.08, Math.min(1, Math.abs(x) * 1.4 + 0.1))
      })
    }

    const data = this._waveData
    const BAR = 3, GAP = 2
    const N   = Math.floor(W / (BAR + GAP))
    const playedX = playedRatio * W

    ctx.clearRect(0, 0, W, H)
    for (let i = 0; i < N; i++) {
      const src = Math.floor((i / N) * data.length)
      const val = data[src] ?? 0.2
      const bh  = Math.max(3, val * H)
      const x   = i * (BAR + GAP)
      ctx.fillStyle = x < playedX ? "#00a884" : "rgba(134,150,160,0.5)"
      ctx.beginPath()
      ctx.roundRect(x, (H - bh) / 2, BAR, bh, 1.5)
      ctx.fill()
    }
  }

  _startAnim() {
    const step = () => {
      if (!this.hasAudioTarget || this.audioTarget.paused) return
      this._animId = requestAnimationFrame(step)
    }
    this._animId = requestAnimationFrame(step)
  }

  _showPlay() {
    if (this.hasPlayIconTarget)  this.playIconTarget.style.display  = ""
    if (this.hasPauseIconTarget) this.pauseIconTarget.style.display = "none"
  }

  _showPause() {
    if (this.hasPlayIconTarget)  this.playIconTarget.style.display  = "none"
    if (this.hasPauseIconTarget) this.pauseIconTarget.style.display = ""
  }
}
