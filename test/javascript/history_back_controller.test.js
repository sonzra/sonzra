import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import HistoryBackController from "../../app/javascript/controllers/history_back_controller.js"

describe("history back controller", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = '<a href="/library/albums" data-controller="history-back" data-action="click->history-back#go">Back</a>'
    application = Application.start()
    application.register("history-back", HistoryBackController)
  })

  afterEach(() => application.stop())

  it("uses browser history when a previous page exists", () => {
    const back = vi.spyOn(window.history, "back").mockImplementation(() => {})
    vi.spyOn(window.history, "length", "get").mockReturnValue(2)

    document.querySelector("a").click()

    expect(back).toHaveBeenCalled()
  })
})
