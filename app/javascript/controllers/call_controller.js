import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"
import {
  HMSReactiveStore,
  selectLocalPeer,
  selectRemotePeers,
  selectVideoTrackByID,
  selectIsLocalAudioEnabled,
  selectIsLocalVideoEnabled,
  selectIsConnectedToRoom
} from "@100mslive/hms-video-store"

export default class extends Controller {
  static targets = [
    "localVideo", "remoteVideo",
    "incomingModal", "activeModal",
    "callerName", "callTypeLabel",
    "muteBtn", "videoBtn", "statusLabel"
  ]

  static values = { userName: String }

  connect() {
    this.channel = null
    this.remoteUserId = null
    this.callType = "video"
    this.pendingOffer = null // { room_id, token, caller_name, caller_id, call_type }
    this.unsubscribes = []

    this.initHms()
    this.setupSignalingChannel()
    this.setupLeaveOnUnload()
  }

  disconnect() {
    this.leaveHms()
    this.channel?.unsubscribe()
    this.unsubscribes.forEach(fn => fn?.())
  }

  initHms() {
    this.hms = new HMSReactiveStore()
    this.hms.triggerOnSubscribe?.()
    this.hmsActions = this.hms.getActions()
    this.hmsStore = this.hms.getStore()
  }

  setupSignalingChannel() {
    const consumer = createConsumer()
    this.channel = consumer.subscriptions.create("CallChannel", {
      received: (data) => this.handleSignal(data)
    })
  }

  setupLeaveOnUnload() {
    this.boundLeave = () => this.hmsActions?.leave?.()
    window.addEventListener("beforeunload", this.boundLeave)
    window.addEventListener("pagehide", this.boundLeave)
  }

  handleSignal(data) {
    switch (data.type) {
      case "call_offer":   return this.handleOffer(data)
      case "call_rejected": return this.handleRejected()
      case "call_ended":   return this.handleRemoteEnd()
    }
  }

  // ─── Start call (caller) ─────────────────────────────────────────────────

  async startCall(event) {
    const btn = event.currentTarget
    this.remoteUserId = btn.dataset.userId
    this.callType = btn.dataset.callType || "video"
    const conversationId = btn.dataset.conversationId

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const res = await fetch("/calls", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({
        conversation_id: conversationId,
        call_type: this.callType
      })
    })

    if (!res.ok) {
      const err = await res.json().catch(() => ({}))
      alert(err.error || "Não foi possível iniciar a chamada.")
      return
    }

    const { room_id, token } = await res.json()
    this.showActiveModal("Entrando...", this.callType)

    try {
      await this.joinRoom(token)
    } catch (err) {
      console.error(err)
      alert("Falha ao entrar na sala: " + (err?.message || err))
      this.hangup()
    }
  }

  // ─── Incoming call ──────────────────────────────────────────────────────

  handleOffer(data) {
    this.pendingOffer = {
      room_id: data.room_id,
      token: data.token,
      caller_name: data.caller_name,
      caller_id: data.caller_id,
      call_type: data.call_type || "video"
    }
    this.remoteUserId = String(data.caller_id)
    this.callType = this.pendingOffer.call_type

    if (this.hasCallerNameTarget) this.callerNameTarget.textContent = data.caller_name || "Alguém"
    if (this.hasCallTypeLabelTarget) this.callTypeLabelTarget.textContent = this.callType === "video" ? "📹 Chamada de vídeo" : "📞 Chamada de voz"
    this.incomingModalTarget?.classList.remove("hidden")
  }

  async acceptCall() {
    this.incomingModalTarget?.classList.add("hidden")
    const { token } = this.pendingOffer || {}
    if (!token) return
    this.showActiveModal("Entrando...", this.callType)
    try {
      await this.joinRoom(token)
    } catch (err) {
      console.error(err)
      alert("Falha ao entrar na sala: " + (err?.message || err))
      this.hangup()
    }
    this.pendingOffer = null
  }

  rejectCall() {
    this.incomingModalTarget?.classList.add("hidden")
    if (this.remoteUserId) {
      this.channel.perform("reject", { to_user_id: this.remoteUserId })
    }
    this.remoteUserId = null
    this.pendingOffer = null
  }

  // ─── Room join & video attach ─────────────────────────────────────────────

  async joinRoom(authToken) {
    const userName = this.userNameValue || "User"
    await this.hmsActions.join({
      userName,
      authToken,
      settings: {
        isAudioMuted: false,
        isVideoMuted: this.callType === "audio"
      },
      rememberDeviceSelection: true
    })

    this.attachVideos()
    this.subscribeToConnectionState()
    if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = "Em chamada"
  }

  attachVideos() {
    // Local peer → localVideo (subscribe so we attach when local peer has video track)
    const unsubLocal = this.hmsStore.subscribe((peer) => {
      if (!peer?.videoTrack || !this.hasLocalVideoTarget) return
      const track = this.hmsStore.getState(selectVideoTrackByID(peer.videoTrack))
      if (track?.enabled) this.hmsActions.attachVideo(track.id, this.localVideoTarget)
    }, selectLocalPeer)

    // First remote peer → remoteVideo
    const unsubRemote = this.hmsStore.subscribe((peers) => {
      const peer = Array.isArray(peers) ? (peers.find(p => p.videoTrack) || peers[0]) : null
      if (!peer || !this.hasRemoteVideoTarget) return
      if (peer.videoTrack) {
        const track = this.hmsStore.getState(selectVideoTrackByID(peer.videoTrack))
        if (track?.enabled) this.hmsActions.attachVideo(track.id, this.remoteVideoTarget)
      }
    }, selectRemotePeers)

    this.unsubscribes.push(unsubLocal, unsubRemote)
  }

  subscribeToConnectionState() {
    const unsub = this.hmsStore.subscribe((connected) => {
      if (this.hasStatusLabelTarget) {
        this.statusLabelTarget.textContent = connected ? "Em chamada" : "Desconectado"
      }
    }, selectIsConnectedToRoom)
    this.unsubscribes.push(unsub)
  }

  // ─── Rejected / ended ─────────────────────────────────────────────────────

  handleRejected() {
    this.showToast("Chamada recusada.")
    this.hangup()
  }

  handleRemoteEnd() {
    this.showToast("A chamada foi encerrada.")
    this.hangup()
  }

  // ─── In-call controls ─────────────────────────────────────────────────────

  async toggleMute() {
    const enabled = this.hmsStore.getState(selectIsLocalAudioEnabled)
    await this.hmsActions.setLocalAudioEnabled(!enabled)
    if (this.hasMuteBtnTarget) {
      this.muteBtnTarget.querySelector("span:last-child").textContent = enabled ? "Ativar mic" : "Mudo"
    }
  }

  async toggleVideo() {
    const enabled = this.hmsStore.getState(selectIsLocalVideoEnabled)
    await this.hmsActions.setLocalVideoEnabled(!enabled)
    if (this.hasVideoBtnTarget) {
      this.videoBtnTarget.querySelector("span:last-child").textContent = enabled ? "Ativar câmera" : "Câmera off"
    }
  }

  endCall() {
    if (this.remoteUserId) {
      this.channel.perform("end_call", { to_user_id: this.remoteUserId })
    }
    this.leaveHms()
    this.hangup()
  }

  leaveHms() {
    window.removeEventListener("beforeunload", this.boundLeave)
    window.removeEventListener("pagehide", this.boundLeave)
    this.unsubscribes.forEach(fn => fn?.())
    this.unsubscribes = []
    this.hmsActions?.leave?.()
  }

  hangup() {
    this.leaveHms()
    this.remoteUserId = null
    this.pendingOffer = null
    if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = null
    if (this.hasRemoteVideoTarget) this.remoteVideoTarget.srcObject = null
    this.activeModalTarget?.classList.add("hidden")
    this.incomingModalTarget?.classList.add("hidden")
  }

  showActiveModal(status, callType) {
    if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = status
    if (this.hasCallTypeLabelTarget) this.callTypeLabelTarget.textContent = callType === "video" ? "📹 Vídeo" : "📞 Voz"
    this.activeModalTarget?.classList.remove("hidden")
  }

  showToast(msg) {
    const el = document.createElement("div")
    el.className = "fixed top-4 right-4 z-50 bg-[#202c33] text-white text-sm px-4 py-3 rounded-lg shadow-lg"
    el.textContent = msg
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 4000)
  }
}
