import "@hotwired/turbo-rails"
import "@rails/actioncable"
import "controllers"

// Play notification sound when a push is received (message from service worker).
// Tries /sounds/notification.mp3 first; falls back to a short Web Audio beep if missing.
if (typeof navigator !== "undefined" && navigator.serviceWorker) {
  function playNotificationSound() {
    const audio = new Audio("/sounds/notification.mp3");
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
    if (event.data?.type === "play-notification-sound") playNotificationSound();
  });
}
