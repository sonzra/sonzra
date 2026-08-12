import { defineConfig } from "vitest/config"
import { fileURLToPath, URL } from "node:url"

export default defineConfig({
  resolve: {
    alias: {
      offline_media_store: fileURLToPath(new URL("./app/javascript/offline_media_store.js", import.meta.url))
    }
  },
  test: {
    environment: "jsdom",
    environmentOptions: {
      jsdom: { url: "http://sonzra.test" }
    },
    include: [ "test/javascript/**/*.test.js" ],
    clearMocks: true
  }
})
