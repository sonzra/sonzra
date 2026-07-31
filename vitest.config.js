import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    environment: "jsdom",
    environmentOptions: {
      jsdom: { url: "http://sonzra.test" }
    },
    include: [ "test/javascript/**/*.test.js" ],
    clearMocks: true
  }
})
