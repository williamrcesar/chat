import "@hotwired/turbo-rails"
import "@rails/actioncable"
import "controllers"

// Disable browser scroll restoration so Turbo doesn't fight our scroll-to-bottom
if (history.scrollRestoration) {
  history.scrollRestoration = "manual"
}

// After any Turbo navigation, immediately scroll the messages container to the bottom
document.addEventListener("turbo:load", () => {
  const container = document.getElementById("messages-container")
  if (container) {
    container.scrollTop = container.scrollHeight
    const anchor = document.getElementById("messages-bottom")
    if (anchor) anchor.scrollIntoView({ behavior: "instant", block: "end" })
  }
})

// Play notification sound when a push is received (message from service worker).
// Tries /sounds/notification.mp3 first; falls back to a short Web Audio beep if missing.
if (typeof navigator !== "undefined" && navigator.serviceWorker) {
  function playNotificationSound(soundSrc) {
    const src = soundSrc || "/sounds/notification.mp3";
    const audio = new Audio(src);
    audio.volume = 0.6;
    audio.play().catch(() => {
      try {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        if (!Ctx) return;
        const ctx = new Ctx();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.frequency.value = 880;
        osc.type = "sine";
        gain.gain.setValueAtTime(0.15, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.15);
        osc.start(ctx.currentTime);
        osc.stop(ctx.currentTime + 0.15);
      } catch (_) {}
    });
  }

  navigator.serviceWorker.addEventListener("message", (event) => {
    if (event.data?.type === "play-notification-sound") playNotificationSound(event.data.sound);
  });
}
