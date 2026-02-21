import { Controller } from "@hotwired/stimulus"

// Manages the Web Push subscription lifecycle:
//   1. Registers the PWA service worker
//   2. Requests notification permission from the browser
//   3. Creates a PushSubscription using the server VAPID public key
//   4. POSTs the subscription to /web_push_subscriptions for the server to store
//
// Attach to a button:
//   <button data-controller="push-notifications"
//           data-action="click->push-notifications#subscribe">
//     Enable notifications
//   </button>

export default class extends Controller {
  static targets = ["button", "status"]
  static values  = { subscribed: Boolean }

  async connect() {
    if (!this._supported()) return

    const reg  = await this._registerServiceWorker()
    if (!reg) return

    const sub = await reg.pushManager.getSubscription()
    if (sub) {
      this._markSubscribed()
    } else {
      this._markUnsubscribed()
    }
  }

  // Called when the user clicks the "Enable notifications" button
  async subscribe(event) {
    event.preventDefault()
    if (!this._supported()) {
      alert("Your browser does not support push notifications.")
      return
    }

    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      this._updateStatus("Notifications blocked by browser.")
      return
    }

    const reg = await this._registerServiceWorker()
    if (!reg) return

    try {
      // Fetch the VAPID public key from the server
      const keyRes    = await fetch("/web_push_subscriptions/vapid_public_key")
      const { vapid_public_key } = await keyRes.json()

      // Create a PushSubscription
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly:      true,
        applicationServerKey: this._urlBase64ToUint8Array(vapid_public_key)
      })

      // Send it to the server
      const csrfToken = document.querySelector("meta[name=csrf-token]")?.content
      await fetch("/web_push_subscriptions", {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token":  csrfToken
        },
        body: JSON.stringify({ subscription: sub.toJSON() })
      })

      this._markSubscribed()
    } catch (err) {
      console.error("[PushNotifications] Subscribe failed:", err)
      this._updateStatus("Could not enable notifications.")
    }
  }

  // Called when the user wants to unsubscribe
  async unsubscribe(event) {
    event.preventDefault()
    const reg = await navigator.serviceWorker.ready
    const sub = await reg.pushManager.getSubscription()
    if (!sub) return

    const csrfToken = document.querySelector("meta[name=csrf-token]")?.content
    await fetch("/web_push_subscriptions", {
      method:  "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token":  csrfToken
      },
      body: JSON.stringify({ endpoint: sub.endpoint })
    })
    await sub.unsubscribe()
    this._markUnsubscribed()
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  _supported() {
    return "serviceWorker" in navigator && "PushManager" in window
  }

  async _registerServiceWorker() {
    try {
      return await navigator.serviceWorker.register("/service-worker", { scope: "/" })
    } catch (err) {
      console.error("[PushNotifications] SW registration failed:", err)
      return null
    }
  }

  _markSubscribed() {
    this.subscribedValue = true
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent  = "Notifications ON"
      this.buttonTarget.dataset.action = "click->push-notifications#unsubscribe"
      this.buttonTarget.classList.add("text-[#00a884]")
      this.buttonTarget.classList.remove("text-[#8696a0]")
    }
    if (this.hasStatusTarget) this.statusTarget.textContent = ""
  }

  _markUnsubscribed() {
    this.subscribedValue = false
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent  = "Enable notifications"
      this.buttonTarget.dataset.action = "click->push-notifications#subscribe"
      this.buttonTarget.classList.remove("text-[#00a884]")
      this.buttonTarget.classList.add("text-[#8696a0]")
    }
  }

  _updateStatus(msg) {
    if (this.hasStatusTarget) this.statusTarget.textContent = msg
  }

  // Converts the URL-safe base64 VAPID public key to a Uint8Array required by
  // pushManager.subscribe()
  _urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64  = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const raw     = atob(base64)
    return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)))
  }
}
