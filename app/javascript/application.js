import "@hotwired/turbo-rails"
import "controllers"

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js?v=7").catch(() => {
      // Offline playback remains optional when a browser blocks service workers.
    })
  })
}
