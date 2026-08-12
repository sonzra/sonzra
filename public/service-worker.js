const OFFLINE_MEDIA_CACHE = "sonzra-offline-media-v1"
const OFFLINE_SHELL_CACHE = "sonzra-offline-shell-v2"
const OFFLINE_ASSET_CACHE = "sonzra-offline-assets-v1"
const OFFLINE_MEDIA_PATH = /^\/server_connections\/[^/]+\/(?:audio|artwork)\/[^/]+$/
const OFFLINE_SHELL_PATH = "/offline_shell"
const OFFLINE_ASSET_PATH = /^\/(?:assets\/|brand\/|manifest\.json$|(?:icon|favicon|apple-touch-icon)[\w-]*\.(?:png|svg|ico)$)/

self.addEventListener("install", () => self.skipWaiting())
self.addEventListener("activate", event => event.waitUntil(self.clients.claim()))

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

async function documentOrOfflineShell(request) {
  try {
    return await fetch(request)
  } catch (_) {
    const cache = await caches.open(OFFLINE_SHELL_CACHE)
    return await cache.match(OFFLINE_SHELL_PATH) || new Response("Sonzra downloads are not available offline yet.", { status: 503, headers: { "Content-Type": "text/plain" } })
  }
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
    const cache = await caches.open(OFFLINE_MEDIA_CACHE)
    const offlineCopy = await cache.match(request.url, { ignoreVary: true })

    return offlineCopy ? rangeResponse(request, offlineCopy) : fetch(request)
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
