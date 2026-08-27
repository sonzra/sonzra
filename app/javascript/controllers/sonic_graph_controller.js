import { Controller } from "@hotwired/stimulus"
import "graphology"
import "sigma"
import FA2 from "forceatlas2"

export default class extends Controller {
  static targets = [ "container", "search", "panel", "loader" ]
  static values = { data: Object }

  connect() {
    this.container = this.containerTarget
    this.search = this.hasSearchTarget ? this.searchTarget : null
    this.panel = this.hasPanelTarget ? this.panelTarget : null
    this.loader = this.hasLoaderTarget ? this.loaderTarget : null
    this.renderer = null
    this.graph = null
    this.imageCache = new Map()
    this.searchQuery = ""
    setTimeout(() => this.loadGraph(), 20)
  }

  disconnect() {
    if (this.renderer) {
      this.renderer.kill()
      this.renderer = null
    }
  }

  formatImageUrl(url) {
    if (!url) return `${window.location.origin}/brand/sonzra-mark.svg`
    return url.startsWith("http") ? url : `${window.location.origin}${url}`
  }

  resetZoom() {
    if (this.renderer) {
      if (this.search) this.search.value = ""
      this.searchQuery = ""
      this.renderer.getCamera().animate(
        { x: 0.5, y: 0.5, ratio: 1.5, angle: 0 },
        { duration: 500, easing: "quadraticOut" }
      )
      if (this.panel) this.panel.style.display = "none"
      this.renderer.refresh()
    }
  }

  onSearch(e) {
    this.searchQuery = (e.target.value || "").trim().toLowerCase()
    if (!this.renderer || !this.graph) return

    if (this.searchQuery.length > 0) {
      const matches = []
      this.graph.forEachNode((node, attrs) => {
        const title = (attrs.title || attrs.label || "").toLowerCase()
        const artist = (attrs.artist || attrs.group || "").toLowerCase()
        if (title.includes(this.searchQuery) || artist.includes(this.searchQuery)) {
          matches.push(node)
        }
      })

      if (matches.length > 0) {
        const firstMatch = matches[0]
        const displayData = this.renderer.getNodeDisplayData(firstMatch)
        if (displayData) {
          this.renderer.getCamera().animate(
            { x: displayData.x, y: displayData.y, ratio: 0.3 },
            { duration: 500, easing: "quadraticOut" }
          )
        }
      }
    }

    this.renderer.refresh()
  }

  resolveOverlaps() {
    if (!this.graph) return

    const nodeCount = this.graph.order
    // Skip for very large graphs (O(n²) is too expensive)
    if (nodeCount > 5000) return

    for (let pass = 0; pass < 3; pass++) {
      const startTime = performance.now()
      const nodes = []
      this.graph.forEachNode((id, attrs) => {
        nodes.push({ id, x: attrs.x, y: attrs.y, size: attrs.size || 4 })
      })

      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const a = nodes[i]
          const b = nodes[j]
          const dx = a.x - b.x
          const dy = a.y - b.y
          const dist = Math.sqrt(dx * dx + dy * dy)
          const minDist = (a.size + b.size) * 3
          if (dist < minDist && dist > 0) {
            const push = (minDist - dist) / 2
            const ux = (dx / dist) * push
            const uy = (dy / dist) * push
            a.x += ux
            a.y += uy
            b.x -= ux
            b.y -= uy
          }
        }
      }

      // Write back
      nodes.forEach(n => {
        this.graph.setNodeAttribute(n.id, "x", n.x)
        this.graph.setNodeAttribute(n.id, "y", n.y)
      })

      // Bail if pass took too long (>100ms)
      if (performance.now() - startTime > 100) break
    }
  }

  loadGraph() {
    const rawData = this.dataValue
    if (!rawData) return

    const GraphClass = window.graphology?.Graph || window.Graphology?.Graph || window.graphology || window.Graphology
    const SigmaClass = window.Sigma || window.sigma?.Sigma || window.sigma || window.Sigma

    if (!GraphClass || !SigmaClass) {
      console.warn("[SonicGraph] Sigma.js or Graphology module resolution:", { windowGraphology: window.graphology, windowSigma: window.Sigma })
      return
    }

    this.graph = new GraphClass({ multi: false, type: "undirected" })
    const palette = [
      "#ec4899", "#8b5cf6", "#3b82f6", "#10b981", "#f59e0b",
      "#ef4444", "#06b6d4", "#84cc16", "#a855f7", "#6366f1"
    ]
    const groupColors = {}

    let nodes = []
    let edges = []

    // Fermat spiral golden angle for uniform radial distribution
    const goldenAngle = Math.PI * (3 - Math.sqrt(5))

    if (rawData.center) {
      // Single track local galaxy mode
      const center = rawData.center
      nodes.push({
        id: String(center.item_id),
        label: center.title,
        title: center.title,
        artist: center.artist,
        artwork: center.artwork,
        audio_url: center.audio_url,
        group: center.artist,
        degree: (rawData.neighbors || []).length,
        x: 0,
        y: 0,
        size: 14,
        color: "#ec4899"
      })

      if (rawData.neighbors) {
        rawData.neighbors.forEach((n, idx) => {
          const angle = (idx / rawData.neighbors.length) * Math.PI * 2
          const radius = 120 + (n.distance || 0.5) * 150
          nodes.push({
            id: String(n.item_id),
            label: n.title,
            title: n.title,
            artist: n.artist,
            artwork: n.artwork,
            audio_url: n.audio_url,
            group: n.artist,
            degree: 1,
            x: Math.cos(angle) * radius,
            y: Math.sin(angle) * radius,
            size: 6,
            color: "#3b82f6"
          })
          edges.push({ from: String(center.item_id), to: String(n.item_id), weight: 1.0 - (n.distance || 0.5) })
        })
      }
    } else if (rawData.nodes) {
      // Multi-cluster library cartography mode — Organic Galaxy Cloud Initialization
      const groupCounts = {}
      rawData.nodes.forEach(n => {
        const g = n.group || "Library"
        groupCounts[g] = (groupCounts[g] || 0) + 1
      })

      let paletteIdx = 0
      Object.keys(groupCounts).forEach(g => {
        groupColors[g] = palette[paletteIdx % palette.length]
        paletteIdx++
      })

      rawData.nodes.forEach((n) => {
        const g = n.group || "Library"
        const deg = n.degree || 1
        const nodeSize = Math.min(10.0, Math.max(3.5, Math.sqrt(deg) * 1.2))

        // Natural uniform disk seeding (R = 3000) — avoids artificial pinwheel arms
        const angle = Math.random() * Math.PI * 2
        const radius = Math.sqrt(Math.random()) * 3000

        nodes.push({
          id: String(n.id),
          label: `${n.label} - ${g}`,
          title: n.label,
          artist: g,
          artwork: n.image,
          image: n.image,
          audio_url: n.audio_url,
          group: g,
          degree: deg,
          x: Math.cos(angle) * radius,
          y: Math.sin(angle) * radius,
          size: nodeSize,
          color: groupColors[g] || "#3b82f6"
        })
      })

      edges = (rawData.edges || []).map(e => ({
        from: String(e.from),
        to: String(e.to),
        weight: e.value || 1
      }))
    }

    // Add nodes & edges to Graphology graph
    nodes.forEach(n => {
      if (!this.graph.hasNode(n.id)) {
        this.graph.addNode(n.id, {
          label: n.label,
          title: n.title,
          artist: n.artist,
          artwork: n.artwork,
          image: n.image,
          audio_url: n.audio_url,
          degree: n.degree,
          x: n.x,
          y: n.y,
          size: n.size,
          color: n.color
        })
      }
    })

    edges.forEach(e => {
      if (this.graph.hasNode(e.from) && this.graph.hasNode(e.to) && !this.graph.hasEdge(e.from, e.to)) {
        this.graph.addEdge(e.from, e.to, {
          size: 0.1,
          color: "rgba(0, 0, 0, 0)"
        })
      }
    })

    // ForceAtlas2: Organic galaxy clustering guided purely by acoustic edge attractions
    const fa2 = (FA2 && typeof FA2.assign === "function") ? FA2 : (FA2?.default || window.FA2Layout || window.forceAtlas2 || window.graphologyLayoutForceAtlas2)
    if (fa2 && typeof fa2.assign === "function") {
      try {
        fa2.assign(this.graph, {
          iterations: 350,
          settings: {
            gravity: 0.2,
            scalingRatio: 4000,
            linLogMode: true,
            outboundAttractionDistribution: true,
            barnesHutOptimize: true,
            barnesHutTheta: 0.5,
            adjustSizes: true,
            slowDown: 4
          }
        })
      } catch (err) {
        // Fallback
      }
    }

    // Post-layout overlap resolution
    this.resolveOverlaps()

    // Custom Canvas Hover Renderer with Cover Art & High-Contrast Pill
    const customHoverRenderer = (context, data, settings) => {
      const size = data.size || 6
      const font = settings.labelFont || "sans-serif"
      const weight = settings.labelWeight || "600"
      const fontSize = settings.labelSize || 13

      context.font = `${weight} ${fontSize}px ${font}`
      const label = data.label || ""
      if (!label) return

      const textWidth = context.measureText(label).width
      const x = Math.round(data.x)
      const y = Math.round(data.y)
      const padding = 6
      const boxHeight = fontSize + padding * 2

      // Check for cover art image in cache or trigger load
      const imgUrl = this.formatImageUrl(data.artwork || data.image)
      let img = null
      if (imgUrl) {
        img = this.imageCache.get(imgUrl)
        if (!img) {
          img = new Image()
          img.crossOrigin = "anonymous"
          img.src = imgUrl
          this.imageCache.set(imgUrl, img)
          img.onload = () => {
            if (this.renderer) this.renderer.refresh()
          }
        }
      }

      const hasThumb = img && img.complete && img.naturalWidth > 0
      const thumbSize = 24
      const extraWidth = hasThumb ? thumbSize + 6 : 0
      const boxWidth = textWidth + padding * 2 + extraWidth

      // Draw artwork clipped inside the node circle
      if (hasThumb) {
        context.save()
        context.beginPath()
        context.arc(x, y, size + 3, 0, Math.PI * 2)
        context.clip()
        context.drawImage(img, x - size - 3, y - size - 3, (size + 3) * 2, (size + 3) * 2)
        context.restore()

        // Ring border around cover art circle
        context.beginPath()
        context.arc(x, y, size + 3, 0, Math.PI * 2)
        context.strokeStyle = data.color || "#ec4899"
        context.lineWidth = 2
        context.stroke()
      } else {
        // Draw node circle highlight ring
        context.beginPath()
        context.arc(x, y, size + 3, 0, Math.PI * 2)
        context.fillStyle = data.color || "#ec4899"
        context.fill()
      }

      // Draw Dark Backdrop Pill
      const rx = x + size + 6
      const ry = y - boxHeight / 2
      context.fillStyle = "rgba(15, 23, 42, 0.95)"
      context.strokeStyle = "rgba(255, 255, 255, 0.25)"
      context.lineWidth = 1

      context.beginPath()
      if (typeof context.roundRect === "function") {
        context.roundRect(rx, ry, boxWidth, boxHeight, 6)
      } else {
        context.rect(rx, ry, boxWidth, boxHeight)
      }
      context.fill()
      context.stroke()

      // Draw cover art thumbnail inside pill
      if (hasThumb) {
        context.save()
        context.beginPath()
        const tx = rx + padding
        const ty = ry + (boxHeight - thumbSize + 4) / 2
        if (typeof context.roundRect === "function") {
          context.roundRect(tx, ty, thumbSize - 4, thumbSize - 4, 4)
        } else {
          context.rect(tx, ty, thumbSize - 4, thumbSize - 4)
        }
        context.clip()
        context.drawImage(img, tx, ty, thumbSize - 4, thumbSize - 4)
        context.restore()
      }

      // Draw Crisp White Text
      context.fillStyle = "#ffffff"
      context.fillText(label, rx + padding + extraWidth, ry + fontSize + padding / 2 - 2)
    }

    // Initialize WebGL Sigma.js Renderer
    this.renderer = new SigmaClass(this.graph, this.container, {
      renderEdgeLabels: false,
      defaultNodeColor: "#3b82f6",
      defaultEdgeColor: "rgba(0, 0, 0, 0)",
      defaultNodeType: "circle",
      defaultEdgeType: "line",
      labelFont: "sans-serif",
      labelSize: 13,
      labelWeight: "600",
      labelColor: { color: "#ffffff" },
      hoverRenderer: customHoverRenderer,
      labelRenderedSizeThreshold: 10,
      stagePadding: 20
    })

    // Set initial camera ratio to view the widely spread constellation
    this.renderer.getCamera().setState({ ratio: 1.5 })

    // Hover & Selection State
    let hoveredNode = null
    let selectedNode = null
    const activeNeighbors = new Set()

    const updateActiveState = () => {
      const active = selectedNode || hoveredNode
      activeNeighbors.clear()
      if (active && this.graph.hasNode(active)) {
        this.graph.neighbors(active).forEach(n => activeNeighbors.add(n))
      }
      this.renderer.refresh()
    }

    this.renderer.on("enterNode", ({ node }) => {
      hoveredNode = node
      updateActiveState()
    })

    this.renderer.on("leaveNode", () => {
      hoveredNode = null
      updateActiveState()
    })

    this.renderer.on("clickStage", () => {
      selectedNode = null
      updateActiveState()
      if (this.panel) this.panel.style.display = "none"
    })

    // Click to Select Node & Open Detail Panel (Pinned Selection)
    this.renderer.on("clickNode", ({ node }) => {
      if (this.graph.hasNode(node)) {
        selectedNode = node
        updateActiveState()

        const attrs = this.graph.getNodeAttributes(node)
        const displayData = this.renderer.getNodeDisplayData(node)

        if (displayData) {
          this.renderer.getCamera().animate(
            { x: displayData.x, y: displayData.y, ratio: 0.35 },
            { duration: 500, easing: "quadraticOut" }
          )
        }

        if (this.panel) {
          const imgUrl = this.formatImageUrl(attrs.artwork || attrs.image)
          const neighborCount = this.graph.hasNode(node) ? this.graph.degree(node) : (attrs.degree || 0)
          this.panel.innerHTML = `
            <div style="display: flex; align-items: start; justify-content: space-between; margin-bottom: 0.75rem;">
              <div style="display: flex; align-items: center; gap: 0.85rem;">
                <img src="${imgUrl}" style="width: 54px; height: 54px; border-radius: 8px; object-fit: cover; box-shadow: 0 4px 12px rgba(0,0,0,0.4);" />
                <div>
                  <div style="font-weight: 700; font-size: 1rem; color: #fff; text-overflow: ellipsis; overflow: hidden; white-space: nowrap; max-width: 180px;">${attrs.title || attrs.label}</div>
                  <div style="font-size: 0.825rem; color: #94a3b8; margin-top: 2px;">${attrs.artist || ""}</div>
                </div>
              </div>
              <button id="close-sonic-panel" style="background: none; border: none; color: #94a3b8; cursor: pointer; padding: 2px;">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
              </button>
            </div>
            <div style="font-size: 0.8rem; color: #cbd5e1; margin: 0.5rem 0; background: rgba(255,255,255,0.05); padding: 0.5rem; border-radius: 6px;">
              <div>⚡ <strong>Acoustic Neighbors:</strong> ${neighborCount} tracks</div>
            </div>
          `
          this.panel.style.display = "block"

          const closeBtn = document.getElementById("close-sonic-panel")
          if (closeBtn) {
            closeBtn.onclick = () => {
              this.panel.style.display = "none"
              selectedNode = null
              updateActiveState()
            }
          }
        }
      }
    })

    // Node Reducer: Persistent focus on selected / hovered track and its neighbors
    this.renderer.setSetting("nodeReducer", (node, data) => {
      const res = { ...data }

      if (this.searchQuery.length > 0) {
        const title = (data.title || data.label || "").toLowerCase()
        const artist = (data.artist || "").toLowerCase()
        if (title.includes(this.searchQuery) || artist.includes(this.searchQuery)) {
          res.highlighted = true
          res.size = data.size * 1.6
          res.color = "#ec4899"
          res.label = `${data.title} (${data.artist})`
        } else {
          res.color = "rgba(30, 41, 59, 0.15)"
          res.label = ""
        }
        return res
      }

      const active = selectedNode || hoveredNode
      if (active) {
        if (node === active) {
          res.highlighted = true
          res.size = data.size * 1.6
          res.color = "#ec4899"
          res.label = `${data.title} (${data.artist})`
        } else if (activeNeighbors.has(node)) {
          res.highlighted = true
          res.size = data.size * 1.3
          res.color = "#38bdf8"
          res.label = `${data.title}`
        } else {
          res.color = "rgba(51, 65, 85, 0.12)"
          res.label = ""
        }
      }

      return res
    })

    // Edge Reducer: ONLY illuminate edges for the active (clicked or hovered) node
    this.renderer.setSetting("edgeReducer", (edge, data) => {
      const res = { ...data }
      const active = selectedNode || hoveredNode
      if (active && this.graph.hasExtremity(edge, active)) {
        res.color = "#ec4899"
        res.size = 2.0
        res.hidden = false
      } else {
        res.color = "rgba(0, 0, 0, 0)"
        res.size = 0
        res.hidden = true
      }
      return res
    })

    // Dismiss loading indicator smoothly once rendered
    requestAnimationFrame(() => {
      if (this.loader) {
        this.loader.classList.add("sonic-graph-canvas__loader--hidden")
        setTimeout(() => {
          if (this.loader) this.loader.style.display = "none"
        }, 400)
      }
    })
  }
}
