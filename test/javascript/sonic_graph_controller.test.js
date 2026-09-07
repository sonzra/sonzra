import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import SonicGraphController from "../../app/javascript/controllers/sonic_graph_controller.js"

describe("sonic graph controller", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `
      <main data-controller="sonic-graph" data-sonic-graph-data-value='{"nodes":[],"edges":[]}'>
        <input data-sonic-graph-target="search">
        <div data-sonic-graph-target="container"></div>
        <div data-sonic-graph-target="panel"></div>
        <div data-sonic-graph-target="loader"></div>
      </main>`
    application = Application.start()
    application.register("sonic-graph", SonicGraphController)
    await new Promise((resolve) => setTimeout(resolve, 30))
  })

  afterEach(() => application?.stop())

  it("formats local artwork URLs against the current Sonzra origin", () => {
    const controller = application.getControllerForElementAndIdentifier(document.querySelector("main"), "sonic-graph")
    expect(controller.formatImageUrl("/server_connections/1/artwork/track")).toBe("http://sonzra.test/server_connections/1/artwork/track")
    expect(controller.formatImageUrl(null)).toBe("http://sonzra.test/brand/sonzra-mark.svg")
  })

  it("does not initialize the map when there are no analyzed tracks", () => {
    expect(document.querySelector("[data-sonic-graph-target='container']").children).toHaveLength(0)
    expect(document.querySelector("[data-sonic-graph-target='loader']")).not.toBeNull()
  })
})
