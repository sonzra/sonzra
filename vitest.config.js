import { defineConfig } from "vitest/config"
import { fileURLToPath, URL } from "node:url"

export default defineConfig({
  resolve: {
    alias: {
      offline_media_store: fileURLToPath(new URL("./app/javascript/offline_media_store.js", import.meta.url)),
      graphology: fileURLToPath(new URL("./app/javascript/vendor/graphology.min.js", import.meta.url)),
      sigma: fileURLToPath(new URL("./app/javascript/vendor/sigma.min.js", import.meta.url)),
      forceatlas2: fileURLToPath(new URL("./app/javascript/vendor/forceatlas2.min.js", import.meta.url))
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
