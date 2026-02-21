import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// ICE / STUN servers (using free Google STUN + optional TURN)
const ICE_SERVERS = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" },
    { urls: "stun:stun1.l.google.com:19302" },
    // TODO: Add TURN server credentials for production NAT traversal:
    // { urls: "turn:your-turn-server.com", username: "user", credential: "pass" }
  ]
}

export default class extends Controller {
  static targets = [
    "localVideo", "remoteVideo",
    "incomingModal", "activeModal",
    "callerName", "callTypeLabel",
    "muteBtn", "videoBtn", "statusLabel"
  ]

  connect() {
    this.channel      = null
    this.pc           = null         // RTCPeerConnection
    this.localStream  = null
    this.remoteUserId = null
    this.callType     = "video"
    this.isMuted      = false
    this.isVideoOff   = false

    this.setupSignalingChannel()
  }

  disconnect() {
    this.hangup()
    this.channel?.unsubscribe()
  }

  // ─── Signaling channel ───────────────────────────────────────────────────

  setupSignalingChannel() {
    const consumer = createConsumer()
    this.channel = consumer.subscriptions.create("CallChannel", {
      received: (data) => this.handleSignal(data)
    })
  }

  handleSignal(data) {
    switch (data.type) {
      case "call_offer":    return this.handleOffer(data)
      case "call_answer":   return this.handleAnswer(data)
      case "ice_candidate": return this.handleIceCandidate(data)
      case "call_rejected": return this.handleRejected()
      case "call_ended":    return this.handleRemoteEnd()
    }
  }

  // ─── Initiate a call ─────────────────────────────────────────────────────

  async startCall(event) {
    const btn           = event.currentTarget
    this.remoteUserId   = btn.dataset.userId
    this.callType       = btn.dataset.callType || "video"
    const conversationId = btn.dataset.conversationId

    await this.acquireMedia()
    this.createPeerConnection()

    // Create and send offer
    const offer = await this.pc.createOffer()
    await this.pc.setLocalDescription(offer)

    this.channel.perform("offer", {
      to_user_id:      this.remoteUserId,
      conversation_id: conversationId,
      call_type:       this.callType,
      sdp:             offer
    })

    this.showActiveModal("Chamando...", this.callType)
  }

  // ─── Incoming call handlers ───────────────────────────────────────────────

  handleOffer(data) {
    this.pendingOffer  = data.sdp
    this.remoteUserId  = data.from_user_id
    this.callType      = data.call_type

    if (this.hasCallerNameTarget)  this.callerNameTarget.textContent  = data.from_user_name
    if (this.hasCallTypeLabelTarget) this.callTypeLabelTarget.textContent = data.call_type === "video" ? "📹 Chamada de vídeo" : "📞 Chamada de voz"

    this.incomingModalTarget?.classList.remove("hidden")
    this.ringAudio?.play().catch(() => {})
  }

  async acceptCall() {
    this.incomingModalTarget?.classList.add("hidden")
    this.ringAudio?.pause()

    await this.acquireMedia()
    this.createPeerConnection()

    await this.pc.setRemoteDescription(new RTCSessionDescription(this.pendingOffer))
    const answer = await this.pc.createAnswer()
    await this.pc.setLocalDescription(answer)

    this.channel.perform("answer", {
      to_user_id: this.remoteUserId,
      sdp:        answer
    })

    this.showActiveModal("Em chamada", this.callType)
  }

  rejectCall() {
    this.incomingModalTarget?.classList.add("hidden")
    this.ringAudio?.pause()
    this.channel.perform("reject", { to_user_id: this.remoteUserId })
    this.remoteUserId = null
    this.pendingOffer = null
  }

  // ─── Call established ─────────────────────────────────────────────────────

  async handleAnswer(data) {
    await this.pc?.setRemoteDescription(new RTCSessionDescription(data.sdp))
    if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = "Em chamada"
  }

  async handleIceCandidate(data) {
    if (data.candidate && this.pc) {
      try {
        await this.pc.addIceCandidate(new RTCIceCandidate(data.candidate))
      } catch (e) { /* ignore stale candidates */ }
    }
  }

  handleRejected() {
    this.showToast("Chamada recusada.")
    this.hangup()
  }

  handleRemoteEnd() {
    this.showToast("A chamada foi encerrada.")
    this.hangup()
  }

  // ─── In-call controls ────────────────────────────────────────────────────

  toggleMute() {
    if (!this.localStream) return
    this.isMuted = !this.isMuted
    this.localStream.getAudioTracks().forEach(t => { t.enabled = !this.isMuted })
    if (this.hasMuteBtnTarget) {
      this.muteBtnTarget.textContent = this.isMuted ? "🔇 Ativar mic" : "🎤 Mudo"
    }
  }

  toggleVideo() {
    if (!this.localStream) return
    this.isVideoOff = !this.isVideoOff
    this.localStream.getVideoTracks().forEach(t => { t.enabled = !this.isVideoOff })
    if (this.hasVideoBtnTarget) {
      this.videoBtnTarget.textContent = this.isVideoOff ? "📷 Ativar câmera" : "📵 Câmera off"
    }
  }

  endCall() {
    if (this.remoteUserId) {
      this.channel.perform("end_call", { to_user_id: this.remoteUserId })
    }
    this.hangup()
  }

  // ─── Internal helpers ────────────────────────────────────────────────────

  async acquireMedia() {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({
        audio: true,
        video: this.callType === "video"
      })
      if (this.hasLocalVideoTarget && this.callType === "video") {
        this.localVideoTarget.srcObject = this.localStream
      }
    } catch (err) {
      alert("Não foi possível acessar câmera/microfone: " + err.message)
      throw err
    }
  }

  createPeerConnection() {
    this.pc = new RTCPeerConnection(ICE_SERVERS)

    // Send local tracks
    this.localStream?.getTracks().forEach(track => {
      this.pc.addTrack(track, this.localStream)
    })

    // Receive remote tracks
    this.pc.ontrack = (event) => {
      if (this.hasRemoteVideoTarget && event.streams[0]) {
        this.remoteVideoTarget.srcObject = event.streams[0]
      }
    }

    // Send ICE candidates to peer
    this.pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.channel.perform("ice_candidate", {
          to_user_id: this.remoteUserId,
          candidate:  event.candidate
        })
      }
    }

    this.pc.onconnectionstatechange = () => {
      if (this.hasStatusLabelTarget) {
        this.statusLabelTarget.textContent = this.pc.connectionState
      }
      if (["failed", "disconnected", "closed"].includes(this.pc.connectionState)) {
        this.hangup()
      }
    }
  }

  hangup() {
    this.localStream?.getTracks().forEach(t => t.stop())
    this.pc?.close()
    this.pc           = null
    this.localStream  = null
    this.remoteUserId = null
    this.isMuted      = false
    this.isVideoOff   = false

    if (this.hasLocalVideoTarget)  this.localVideoTarget.srcObject  = null
    if (this.hasRemoteVideoTarget) this.remoteVideoTarget.srcObject = null
    this.activeModalTarget?.classList.add("hidden")
    this.incomingModalTarget?.classList.add("hidden")
  }

  showActiveModal(status, callType) {
    if (this.hasStatusLabelTarget)   this.statusLabelTarget.textContent   = status
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
