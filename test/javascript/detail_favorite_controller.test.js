import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import DetailFavoriteController from "../../app/javascript/controllers/detail_favorite_controller.js"

describe("detail favorite controller", () => {
  let application

  beforeEach(async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true })))
    document.body.innerHTML = '<button data-controller="detail-favorite" data-detail-favorite-url-value="/favorites/album-1" data-detail-favorite-favorited-value="false" data-action="detail-favorite#toggle"><svg></svg></button>'
    application = Application.start()
    application.register("detail-favorite", DetailFavoriteController)
    await Promise.resolve()
  })

  afterEach(() => {
    application?.stop()
    vi.unstubAllGlobals()
  })

  it("optimistically marks an item as a favourite", async () => {
    const button = document.querySelector("button")

    await button.click()
    await Promise.resolve()

    expect(button.classList).toContain("is-active")
    expect(button.getAttribute("aria-label")).toBe("Remove from favourites")
    expect(fetch).toHaveBeenCalledWith("/favorites/album-1", expect.objectContaining({ method: "PATCH", body: JSON.stringify({ favorite: true }) }))
  })
})
