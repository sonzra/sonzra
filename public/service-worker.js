const OFFLINE_MEDIA_CACHE = "sonzra-offline-media-v1"
const EPHEMERAL_STREAM_CACHE = "sonzra-stream-cache-v1"
const OFFLINE_SHELL_CACHE = "sonzra-offline-shell-v3"
const OFFLINE_ASSET_CACHE = "sonzra-offline-assets-v2"
const OFFLINE_MEDIA_PATH = /^\/server_connections\/[^/]+\/(?:audio|artwork)\/[^/]+$/
const OFFLINE_SHELL_PATH = "/offline_shell"
const OFFLINE_ASSET_PATH = /^\/(?:assets\/|brand\/|manifest\.json$|(?:icon|favicon|apple-touch-icon)[\w-]*\.(?:png|svg|ico)$)/

const CURRENT_CACHES = [
  OFFLINE_MEDIA_CACHE,
  EPHEMERAL_STREAM_CACHE,
  OFFLINE_SHELL_CACHE,
  OFFLINE_ASSET_CACHE
]

self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    if (globalThis.caches?.keys) {
      const keys = await caches.keys()
      await Promise.all(
        keys.map((key) => {
          if (key.startsWith("sonzra-") && !CURRENT_CACHES.includes(key)) {
            return caches.delete(key)
          }
        })
      )
    }
    await self.clients.claim()
  })())
})

self.addEventListener("fetch", (event) => {
  const requestUrl = new URL(event.request.url)
  if (event.request.method !== "GET" || requestUrl.origin !== self.location.origin) return

  if (isDocumentRequest(event.request)) {
    event.respondWith(documentOrOfflineShell(event.request))
    return
  }

  if (OFFLINE_ASSET_PATH.test(requestUrl.pathname)) {
    event.respondWith(assetCopyOrNetwork(event.request))
    return
  }

  if (!OFFLINE_MEDIA_PATH.test(requestUrl.pathname)) return

  event.respondWith(offlineCopyOrNetwork(event.request))
})

const OFFLINE_RECOVERY_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="theme-color" content="#09090f">
  <title>Sonzra — Offline</title>
  <style>
    :root {
      --rz-bg: #09090f;
      --rz-surface: rgb(18 18 28 / 98%);
      --rz-line: rgb(255 255 255 / 10%);
      --rz-text: #f5f5f7;
      --rz-muted: #9494a8;
      --rz-primary: #7a5af8;
      --rz-primary-light: #9b82ff;
      --rz-accent: #3dd68c;
      --rz-error: #ff4568;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--rz-bg);
      color: var(--rz-text);
      min-height: 100vh;
      min-height: 100dvh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      padding-top: calc(24px + env(safe-area-inset-top));
      padding-bottom: calc(24px + env(safe-area-inset-bottom));
      text-align: center;
      -webkit-font-smoothing: antialiased;
      user-select: none;
      -webkit-user-select: none;
    }
    .recovery-card {
      max-width: 400px;
      width: 100%;
      background: var(--rz-surface);
      border: 1px solid var(--rz-line);
      border-radius: 24px;
      padding: 40px 24px;
      box-shadow: 0 30px 100px rgb(0 0 0 / 75%);
      backdrop-filter: blur(20px);
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .sonzra-mark {
      width: 64px;
      height: 54px;
      margin-bottom: 24px;
    }
    h1 {
      font-size: 22px;
      font-weight: 800;
      letter-spacing: -0.02em;
      margin-bottom: 12px;
      color: var(--rz-text);
    }
    p {
      font-size: 14px;
      line-height: 1.55;
      color: var(--rz-muted);
      margin-bottom: 24px;
      max-width: 320px;
    }
    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 700;
      margin-bottom: 24px;
      background: rgb(255 255 255 / 6%);
      border: 1px solid var(--rz-line);
      color: var(--rz-muted);
      transition: color 0.2s ease, border-color 0.2s ease;
    }
    .status-indicator {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: currentColor;
    }
    .status-badge[data-state="checking"] {
      color: var(--rz-primary-light);
      border-color: rgb(155 130 255 / 35%);
    }
    .status-badge[data-state="online"] {
      color: var(--rz-accent);
      border-color: rgb(61 214 140 / 35%);
    }
    .retry-button {
      min-height: 48px;
      min-width: 180px;
      padding: 0 28px;
      border: 0;
      border-radius: 999px;
      background: var(--rz-primary);
      color: #fff;
      font: inherit;
      font-size: 14px;
      font-weight: 750;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: transform 0.15s ease, background 0.15s ease, opacity 0.15s ease;
      touch-action: manipulation;
      -webkit-tap-highlight-color: transparent;
    }
    .retry-button:hover {
      background: #6c47f7;
      transform: translateY(-1px);
    }
    .retry-button:active {
      transform: translateY(1px);
    }
    .retry-button:focus-visible {
      outline: 2px solid var(--rz-primary-light);
      outline-offset: 3px;
    }
    .retry-button:disabled {
      opacity: 0.6;
      cursor: not-allowed;
      transform: none;
    }
    @media (prefers-reduced-motion: reduce) {
      .retry-button, .status-badge { transition: none; }
      .retry-button:hover, .retry-button:active { transform: none; }
    }
  </style>
</head>
<body>
  <main class="recovery-card">
    <svg class="sonzra-mark" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 236 200" role="img" aria-label="Sonzra">
      <defs>
        <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
          <stop stop-color="#9a66ff"/>
          <stop offset=".56" stop-color="#7658f6"/>
          <stop offset="1" stop-color="#43d7c6"/>
        </linearGradient>
      </defs>
      <rect x="59" y="28" width="10" height="36" rx="5" fill="url(#g)"/>
      <rect x="77" y="22" width="10" height="48" rx="5" fill="url(#g)"/>
      <rect x="95" y="18" width="10" height="58" rx="5" fill="url(#g)"/>
      <rect x="113" y="16" width="10" height="64" rx="5" fill="url(#g)"/>
      <rect x="131" y="18" width="10" height="58" rx="5" fill="url(#g)"/>
      <rect x="149" y="23" width="10" height="48" rx="5" fill="url(#g)"/>
      <rect x="167" y="30" width="10" height="36" rx="5" fill="url(#g)"/>
      <rect x="149" y="60" width="10" height="30" rx="5" fill="url(#g)"/>
      <rect x="131" y="66" width="10" height="38" rx="5" fill="url(#g)"/>
      <rect x="113" y="72" width="10" height="44" rx="5" fill="url(#g)"/>
      <rect x="95" y="78" width="10" height="38" rx="5" fill="url(#g)"/>
      <rect x="77" y="85" width="10" height="30" rx="5" fill="url(#g)"/>
      <rect x="59" y="94" width="10" height="22" rx="5" fill="url(#g)"/>
      <rect x="77" y="116" width="10" height="30" rx="5" fill="url(#g)"/>
      <rect x="95" y="122" width="10" height="38" rx="5" fill="url(#g)"/>
      <rect x="113" y="128" width="10" height="44" rx="5" fill="url(#g)"/>
      <rect x="131" y="134" width="10" height="38" rx="5" fill="url(#g)"/>
      <rect x="149" y="140" width="10" height="30" rx="5" fill="url(#g)"/>
      <rect x="167" y="148" width="10" height="22" rx="5" fill="url(#g)"/>
    </svg>
    <h1>Sonzra is offline</h1>
    <p>Your media server or VPN is unreachable. Check your connection or reconnect your VPN to continue.</p>
    <div class="status-badge" role="status" aria-live="polite" data-state="offline">
      <span class="status-indicator" aria-hidden="true"></span>
      <span class="status-text">Offline — server unreachable</span>
    </div>
    <button type="button" class="retry-button" id="retry-btn">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>
      <span>Retry Connection</span>
    </button>
  </main>
  <script>
    (function() {
      const retryBtn = document.getElementById("retry-btn");
      const badge = document.querySelector(".status-badge");
      const statusText = document.querySelector(".status-text");
      let checking = false;
      let connected = false;

      async function check() {
        if (checking || connected) return;
        checking = true;
        badge.dataset.state = "checking";
        statusText.textContent = "Checking connection…";
        retryBtn.disabled = true;

        try {
          const res = await fetch("/up", { cache: "no-store" });
          if (!res.ok) throw new Error("Unavailable");
          connected = true;
          badge.dataset.state = "online";
          statusText.textContent = "Connected — reloading…";
          setTimeout(() => window.location.reload(), 400);
        } catch (_) {
          badge.dataset.state = "offline";
          statusText.textContent = "Offline — server unreachable";
          retryBtn.disabled = false;
        } finally {
          checking = false;
        }
      }

      retryBtn.addEventListener("click", check);
      window.addEventListener("online", check);
      window.addEventListener("focus", check);
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "visible") check();
      });

      setInterval(check, 3000);
      check();
    })();
  </script>
</body>
</html>`

async function documentOrOfflineShell(request) {
  try {
    return await fetch(request)
  } catch (_) {
    try {
      const cache = await caches.open(OFFLINE_SHELL_CACHE)
      const offlineCopy = await cache.match(OFFLINE_SHELL_PATH)
      if (offlineCopy) return offlineCopy
    } catch (_) {
      // Cache open failure falls through to recovery HTML
    }
    return offlineRecoveryResponse()
  }
}

function offlineRecoveryResponse() {
  return new Response(OFFLINE_RECOVERY_HTML, {
    status: 503,
    statusText: "Service Unavailable",
    headers: { "Content-Type": "text/html; charset=utf-8" }
  })
}

async function assetCopyOrNetwork(request) {
  try {
    const response = await fetch(request)
    if (!response.ok) return response

    const cache = await caches.open(OFFLINE_ASSET_CACHE)
    await cache.put(request, response.clone())
    return response
  } catch (error) {
    const cache = await caches.open(OFFLINE_ASSET_CACHE)
    const offlineCopy = await cache.match(request)
    if (offlineCopy) return offlineCopy
    throw error
  }
}

function isDocumentRequest(request) {
  return request.mode === "navigate" || request.headers.get("Accept")?.includes("text/html")
}

async function offlineCopyOrNetwork(request) {
  try {
    const offlineCache = await caches.open(OFFLINE_MEDIA_CACHE)
    const offlineCopy = await offlineCache.match(request.url, { ignoreVary: true })
    if (offlineCopy) return rangeResponse(request, offlineCopy)

    const streamCache = await caches.open(EPHEMERAL_STREAM_CACHE)
    const streamCopy = await streamCache.match(request.url, { ignoreVary: true })
    if (streamCopy) return rangeResponse(request, streamCopy)

    return fetch(request)
  } catch (_) {
    return fetch(request)
  }
}

async function rangeResponse(request, response) {
  const range = request.headers.get("Range")
  if (!range) return response

  const match = range.match(/^bytes=(\d+)-(\d*)$/)
  if (!match) return response

  const body = await response.arrayBuffer()
  const start = Number(match[1])
  const end = Math.min(match[2] ? Number(match[2]) : body.byteLength - 1, body.byteLength - 1)
  if (start >= body.byteLength || start > end) return new Response(null, { status: 416, headers: { "Content-Range": `bytes */${body.byteLength}` } })

  const headers = new Headers(response.headers)
  headers.set("Accept-Ranges", "bytes")
  headers.set("Content-Range", `bytes ${start}-${end}/${body.byteLength}`)
  headers.set("Content-Length", String(end - start + 1))
  return new Response(body.slice(start, end + 1), { status: 206, statusText: "Partial Content", headers })
}
