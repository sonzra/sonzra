---
title: "iOS PWA Standalone Plain-Text 503 Navigation Lockout and VPN Auto-Reconnect"
date: "2026-11-09"
category: "mobile-webkit"
module: "public/service-worker.js, app/javascript/controllers/offline_connection_controller.js, app/javascript/offline_media_store.js"
problem_type: "runtime_error"
component: "frontend"
severity: "high"
symptoms:
  - "Launching iOS PWA while disconnected from VPN displays a raw plain-text HTTP 503 response"
  - "Application DOM is destroyed and JavaScript, Turbo, and Stimulus controller runtimes are terminated"
  - "Standalone PWA lacks browser reload chrome or address bar, permanently trapping the user until force-quit"
  - "Toggling VPN back on fails to trigger reconnection without manually waiting for interval polling"
root_cause: "platform_incompatibility"
resolution_type: "code_fix"
tags:
  - "ios"
  - "webkit"
  - "pwa"
  - "service-worker"
  - "offline"
  - "vpn"
  - "cache-storage"
---

# iOS PWA Standalone Plain-Text 503 Navigation Lockout and VPN Auto-Reconnect

## Problem
When launching Sonzra as an installed iOS Progressive Web App (PWA) under Safari / WebKit while disconnected from a home network or VPN with zero offline downloaded tracks, users were trapped on a raw plain-text HTTP 503 error screen (`"Sonzra downloads are not available offline yet."`).

In WebKit standalone mode (`display: standalone`), receiving a `text/plain` document causes WebKit to tear down the entire HTML document tree, terminating Turbo, Stimulus, and all active JavaScript runtimes. Because iOS standalone PWAs do not have browser chrome (no address bar, no reload button, and no gestures to reload a plain-text document), users were permanently locked out and unable to reconnect even after turning their VPN back on, unless they manually force-killed the PWA in the iOS App Switcher.

## Symptoms
- Launching the iOS PWA off-VPN showed a raw black-and-white plain-text screen: `"Sonzra downloads are not available offline yet."`.
- Pull-to-refresh gestures, navigation links, and touch controls were completely inoperative because DOM scripts were destroyed.
- Switching to WireGuard or Tailscale, enabling the VPN, and returning to the PWA left the screen stuck on the 503 error.
- Even when offline tracks were pre-cached, stale cache storage keys (`sonzra-offline-shell-v2` vs `sonzra-offline-shell-v3`) prevented the service worker from finding the cached `/offline_shell`.

## What Didn't Work
- **Returning raw HTTP 503 `text/plain` from Service Worker:** On standard desktop browsers, users can hit CMD+R to reload. On iOS standalone PWAs, WebKit destroys the document runtime, leaving the app dead with no recovery mechanism.
- **Relying solely on `window.ononline` events:** When a user switches to WireGuard, Tailscale, or iOS Settings to connect to their VPN, the underlying network interface (Wi-Fi or cellular) never disconnected. Safari does not dispatch `online` or `offline` events on VPN routing changes.
- **Relying solely on `setInterval` polling:** Background timer throttling in WebKit suspends or delays timers when switching apps. Users returning to the PWA had to wait arbitrarily long before the next polling tick executed.
- **Guarding offline shell caching with `store.catalog().length > 0`:** First-time users or users who only stream music never had `/offline_shell` pre-warmed, ensuring they would always hit the un-cached navigation fallback when opening the app offline.

## Solution
We resolved this across five coordinated layers:

1. **Inline HTML5 Fallback in Service Worker (`public/service-worker.js`):**
   Replaced raw `text/plain` 503 responses with a self-contained, inline HTML5 recovery document styled in Sonzra's dark redesign palette (`#09090F` background, `#12121C` surface cards, `#9B82FF` accents). It contains:
   - Safe-area inset padding (`env(safe-area-inset-top)` / `env(safe-area-inset-bottom)`).
   - An inline SVG waveform mark and clear explanation that the server cannot be reached.
   - An ergonomic, $\ge 48\text{px}$ touch-target "Retry Connection" button.
   - An embedded client script that hooks `online`, `focus`, `visibilitychange`, and active `/up` polling every 3 seconds, reloading `window.location.reload()` automatically once the server responds.

2. **App-Switch Lifecycle Listeners (`offline_connection_controller.js`):**
   Bound `document.addEventListener("visibilitychange")` (filtering for `document.visibilityState === "visible"`) and `window.addEventListener("focus")` to immediately probe server health (`/up`) as soon as the user returns from their VPN app or iOS Settings.

3. **Cache Storage Key Alignment & Pruning (`offline_media_store.js` & `service-worker.js`):**
   Unified cache keys across client storage and the service worker to `sonzra-offline-shell-v3` and `sonzra-offline-assets-v2`. Added automatic eviction in the service worker's `activate` event listener to delete obsolete cache versions (`sonzra-offline-shell-v2`, `sonzra-offline-assets-v1`).

4. **Universal Offline Shell Pre-Warming (`offline_media_controller.js`):**
   Removed the `if (store.catalog().length > 0)` check on connect, warming `/offline_shell` and redesign assets for all authenticated users regardless of downloaded track count.

5. **In-App 0-Downloads Recovery Card (`app/views/offline_downloads/index.html.erb`):**
   Added a dedicated `.offline-downloads__recovery` card with an explicit "Retry connection" button meeting $\ge 44\text{px}$ touch-target standards when the offline shell renders with 0 downloads.

## Why This Works
By ensuring the Service Worker navigation fallback always returns `Content-Type: text/html; charset=utf-8` containing a live DOM with its own embedded reconnection loop, WebKit never destroys the document context.

Furthermore, by attaching probes to `visibilitychange` (`visible`) and `focus`, the application responds immediately when the user switches tasks between their VPN tunnel app and Sonzra, without waiting for throttled timers or non-firing network transition events.

## Prevention
- **Service Worker Invariant:** Never return `text/plain` or non-HTML content for `request.mode === "navigate"` fetch requests. Fallbacks must always be valid HTML5 documents with inline styles and reconnection logic.
- **PWA Connection Monitoring Invariant:** In standalone PWAs, never rely solely on `navigator.onLine` or `online` events for connectivity checks. Always pair with `document.visibilityState === "visible"` and `focus` events combined with active health endpoint probes (`/up`).
- **Cache Storage Contract:** Ensure cache name string constants are version-aligned between the service worker and client storage modules, and register cleanup logic in the `activate` event.

## Related Issues
- GitHub Issue [#22](https://github.com/sonzra/sonzra/issues/22): "fix(offline): replace plain-text 503 trap with HTML recovery UI, align cache keys, and add auto-reconnect"
- Pull Request [#25](https://github.com/sonzra/sonzra/pull/25)
- Documented Solution: `docs/solutions/audio-player/ios-pwa-background-queue-advancement-resilience.md`
