---
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---
# Plan: fix(offline): replace plain-text 503 trap with HTML recovery UI, align cache keys, and add auto-reconnect

## Goal Capsule

- **Objective:** Fix the iOS PWA / WebKit standalone trap where launching Sonzra while disconnected from a home network or VPN (with 0 offline downloads) permanently traps the user on a raw plain-text 503 screen ("Sonzra downloads are not available offline yet.") with no browser chrome, no pull-to-refresh, no JavaScript runtime, and no way to retry or reconnect.
- **Means:**
  1. Replace the raw `text/plain` 503 fallback in `public/service-worker.js` with a standalone, self-contained HTML recovery page styled in Sonzra's dark redesign theme with safe-area insets, an inline SVG mark, a touch-accessible "Retry Connection" button, pull-to-refresh handling, and live `/up` polling that reloads the app automatically once connected.
  2. Unify desynchronized cache keys across `public/service-worker.js` and `app/javascript/offline_media_store.js` (`sonzra-offline-shell-v3` and `sonzra-offline-assets-v2`) and add cache eviction for stale legacy cache keys upon service worker activation.
  3. Warm the offline shell and redesign assets for all authenticated users in `app/javascript/controllers/offline_media_controller.js`, removing the `store.catalog().length > 0` guard.
  4. Enhance `app/javascript/controllers/offline_connection_controller.js` with `visibilitychange` and `focus` event listeners to immediately check connectivity when switching back from VPN or Settings apps, and update all registered retry/status targets.
  5. Add a prominent, touch-accessible recovery banner and retry button to `app/views/offline_downloads/index.html.erb` when 0 downloads are present in offline mode.
- **Authority Hierarchy:** Product and User Experience Guidelines (`docs/guidelines/ui_ux.md`, `ui-ux-advisor`), Engineering & Architecture Guidelines (`docs/ENGINEERING.md`, `architect-advisor`), automated quality gate (`bin/quality`).
- **Stop Conditions:** All five implementation units tested and passing locally; RuboCop clean; Rails test suite passing; Vitest suite passing; visual verification complete on desktop and mobile viewports; `bin/quality` exits 0.

## Product Contract

### Requirements

- R1. **No Plain-Text Navigation Traps:** The Service Worker must never return `Content-Type: text/plain` for navigation or document requests. When the network is unreachable and the cached offline shell is not present, it must return an inline HTML5 document (`Content-Type: text/html; charset=utf-8`, HTTP status 503).
- R2. **Self-Contained Dark Theme Recovery UI:** The inline fallback HTML must render with zero external network or stylesheet dependencies, using inline styles strictly adhering to Sonzra's dark aesthetic (`#09090F` background, `#12121C` surface card, `#F5F5F7` text, `--rz-primary-light` accents), safe-area insets (`env(safe-area-inset-top)` / `env(safe-area-inset-bottom)`), an inline SVG waveform mark, informative copy ("Sonzra is offline — Server unreachable"), and a touch-accessible "Retry Connection" button (minimum 44x44px hitbox).
- R3. **Auto-Reconnect on App Return:** The inline fallback HTML and the `offline_connection_controller.js` must listen for `visibilitychange` (when `document.visibilityState === "visible"`) and `focus` events in addition to `online` and polling intervals, immediately probing `/up` when the user returns to the app after toggling VPN or Wi-Fi in iOS Settings.
- R4. **Immediate Auto-Reload Upon Recovery:** When `/up` returns HTTP 200/ok, the recovery UI must transition to a connected state and reload the window (`window.location.reload()`) to restore full application navigation.
- R5. **Cache Key Synchronization:** `public/service-worker.js` and `app/javascript/offline_media_store.js` must use identical cache names: `sonzra-offline-shell-v3` for the offline HTML shell and `sonzra-offline-assets-v2` for the offline application assets. Stale cache names (`sonzra-offline-shell-v2`, `sonzra-offline-assets-v1`) must be purged on service worker activation.
- R6. **Zero-Download Shell Warming:** Any authenticated session must immediately warm `/offline_shell` and current page assets into the cache upon controller connection, ensuring offline navigation works even when the user has not yet downloaded any audio tracks.
- R7. **Prominent Downloads Recovery Banner:** In `app/views/offline_downloads/index.html.erb`, when viewed offline with zero downloaded tracks, a prominent retry banner must be displayed explaining the server disconnection and providing an ergonomic "Retry connection" button wired to `offline-connection#check`.

### Acceptance Examples

- AE1. *First-time user offline launch (0 downloads, no cache warm):* User installs PWA, turns off VPN before shell warming finishes, launches PWA. Service Worker intercepts navigation, catches network failure, misses shell cache, and serves inline HTML recovery page. The screen displays the Sonzra logo, clear explanation, connection badge, and "Retry connection" button. Tapping the button or turning on VPN in background automatically detects `/up` and reloads into the active library.
- AE2. *Authenticated user warm shell launch (0 downloads, shell warmed):* User logs in while connected to VPN. `offline_media_controller` warms `/offline_shell` into `sonzra-offline-shell-v3`. User disconnects VPN and opens PWA. Service Worker serves `/offline_shell` from cache. The downloads page renders with "No downloads yet" and a prominent recovery card offering "Retry connection". Reconnecting VPN and switching back triggers `visibilitychange` / `focus`, checks `/up`, marks connection online, and reloads.
- AE3. *Service worker activation cache cleanup:* When the updated service worker activates, `sonzra-offline-shell-v2` and `sonzra-offline-assets-v1` are deleted from `caches`, leaving only active versioned caches.

## Planning Contract

### Known Technical Decisions (KTDs)

- KTD1. **Inline HTML in Service Worker vs. External Redirect:** WebKit standalone PWA navigations cannot perform network redirects when offline. The fallback must be served directly from `service-worker.js` in the `fetch` event handler as an inline template string with embedded SVG and CSS. No external script or style requests are made.
- KTD2. **Cache Key Versioning:** Shell cache is `sonzra-offline-shell-v3` and asset cache is `sonzra-offline-assets-v2`. `app/javascript/offline_media_store.js` must be updated to reference these exact constants.
- KTD3. **Multi-Target Stimulus Controller:** `offline_connection_controller.js` will support multiple `retry` and `status` targets (`this.retryTargets.forEach(...)`, `this.statusTargets.forEach(...)`), allowing the topbar status indicator and the new downloads page recovery banner to stay in perfect lockstep.
- KTD4. **Touch Target Ergonomics & Safe Areas:** The inline recovery button and the downloads page retry button will both have a minimum bounding box of 48px height and 180px width, complying with the $\ge 44\text{px}$ touch target invariant from `docs/guidelines/ui_ux.md`.

### Sequencing & Dependencies

1. **Phase 1 (Core Storage & Keys):** Align cache keys in `offline_media_store.js`, update its tests, and add cache eviction in `service-worker.js`.
2. **Phase 2 (Service Worker Recovery UI):** Author inline HTML fallback response in `service-worker.js` with embedded dark styling, SVG mark, touch-accessible retry button, and auto-reconnect scripts. Add Vitest coverage in `service_worker.test.js`.
3. **Phase 3 (Universal Warming):** Remove download-count guard in `offline_media_controller.js` so `warmOfflineShell()` executes on connect for all authenticated users.
4. **Phase 4 (Offline Connection Controller):** Add `visibilitychange` and `focus` event listeners and multi-target support in `offline_connection_controller.js`. Add Vitest tests.
5. **Phase 5 (Views & Styles):** Add the recovery banner in `app/views/offline_downloads/index.html.erb` and corresponding `.redesign` styles in `redesign.css`. Add integration test coverage.
6. **Phase 6 (Verification):** Run `npm run test:javascript`, `bin/rails test`, capture desktop and mobile screenshots for visual inspection, and run `bin/quality`.

## Implementation Units

### U1. Cache Key Alignment and Service Worker Cache Eviction
- **Files:**
  - `app/javascript/offline_media_store.js`
  - `public/service-worker.js`
  - `test/javascript/offline_media_store.test.js`
- **Actions:**
  - In `offline_media_store.js`:
    - Set `OFFLINE_SHELL_CACHE = "sonzra-offline-shell-v3"`
    - Set `OFFLINE_ASSET_CACHE = "sonzra-offline-assets-v2"`
    - In `clear()`: ensure `this.cacheStorage.delete(OFFLINE_ASSET_CACHE)` is also invoked alongside `OFFLINE_SHELL_CACHE`.
  - In `public/service-worker.js`:
    - In `activate` event handler, delete all caches starting with `"sonzra-"` that are not in the current active cache set (`OFFLINE_MEDIA_CACHE`, `EPHEMERAL_STREAM_CACHE`, `OFFLINE_SHELL_CACHE`, `OFFLINE_ASSET_CACHE`).
  - In `test/javascript/offline_media_store.test.js`:
    - Update assertions expecting `sonzra-offline-shell-v2` and `sonzra-offline-assets-v1` to check `sonzra-offline-shell-v3` and `sonzra-offline-assets-v2`.
- **Verification:** `npx vitest run test/javascript/offline_media_store.test.js` passes.

### U2. Service Worker Inline HTML Recovery Fallback
- **Files:**
  - `public/service-worker.js`
  - `test/javascript/service_worker.test.js`
- **Actions:**
  - In `public/service-worker.js`:
    - Define `offlineRecoveryResponse()` returning `new Response(OFFLINE_RECOVERY_HTML, { status: 503, headers: { "Content-Type": "text/html; charset=utf-8" } })`.
    - `OFFLINE_RECOVERY_HTML` contains:
      - Clean HTML5 doctype, meta viewport with `viewport-fit=cover`, theme-color `#09090F`.
      - Inline CSS matching Sonzra dark tokens (`#09090F`, `#12121C`, `#9b82ff`, `#3dd68c`, `Manrope`/sans-serif).
      - Inline Sonzra waveform SVG mark.
      - Heading: "Sonzra is offline", description explaining media server / VPN unreachable.
      - Status badge with dot indicator and state (`offline`, `checking`, `online`).
      - Button "Retry Connection" with touch hitbox $\ge 48\text{px}$, hover/active states, and focus ring.
      - Embedded client script listening to `online`, `focus`, `visibilitychange`, and a 3-second interval polling `/up`. On success (`response.ok`), updates status to "Connected" and calls `window.location.reload()`.
    - In `documentOrOfflineShell(request)`:
      - Replace `new Response("Sonzra downloads are not available offline yet.", { status: 503, headers: { "Content-Type": "text/plain" } })` with `offlineRecoveryResponse()`.
  - In `test/javascript/service_worker.test.js`:
    - Add test verifying that when navigation request fails and shell cache is empty, response status is 503, `Content-Type` is `text/html; charset=utf-8`, and the body text contains the recovery UI, "Retry Connection", and `/up` polling script.
- **Verification:** `npx vitest run test/javascript/service_worker.test.js` passes.

### U3. Universal Offline Shell Warming for Authenticated Sessions
- **Files:**
  - `app/javascript/controllers/offline_media_controller.js`
  - `test/javascript/offline_media_controller.test.js` (new or integrated into controller suite)
- **Actions:**
  - In `app/javascript/controllers/offline_media_controller.js`:
    - In `connect()`: change `if (store.catalog().length > 0) store.warmOfflineShell()` to `store.warmOfflineShell()` unconditionally.
  - Create `test/javascript/offline_media_controller.test.js`:
    - Mount controller with Stimulus `Application`.
    - Verify `warmOfflineShell()` is invoked when connecting even if `store.catalog()` is empty (`[]`).
- **Verification:** `npx vitest run test/javascript/offline_media_controller.test.js` passes.

### U4. App-Switch Visibility and Multi-Target Auto-Reconnect
- **Files:**
  - `app/javascript/controllers/offline_connection_controller.js`
  - `test/javascript/offline_connection_controller.test.js`
- **Actions:**
  - In `app/javascript/controllers/offline_connection_controller.js`:
    - Bind `this.boundVisibility = this.handleVisibilityChange.bind(this)`.
    - In `connect()`:
      - Add `window.addEventListener("focus", this.boundCheck)`.
      - Add `document.addEventListener("visibilitychange", this.boundVisibility)`.
    - In `handleVisibilityChange()`:
      - If `document.visibilityState === "visible"`, call `this.check()`.
    - In `disconnect()`:
      - Remove `window.removeEventListener("focus", this.boundCheck)`.
      - Remove `document.removeEventListener("visibilitychange", this.boundVisibility)`.
    - Update `check()`, `setStatus()`, and error handling to operate over `this.statusTargets` and `this.retryTargets` with array iteration (`this.retryTargets.forEach(...)`) so multiple retry buttons and status displays update synchronously.
  - In `test/javascript/offline_connection_controller.test.js`:
    - Add test: triggering `visibilitychange` with `document.visibilityState = "visible"` executes `check()`.
    - Add test: window `focus` event executes `check()`.
    - Add test: multiple retry targets and status targets are updated together.
- **Verification:** `npx vitest run test/javascript/offline_connection_controller.test.js` passes.

### U5. Offline Downloads Recovery Banner (0 Downloads State)
- **Files:**
  - `app/views/offline_downloads/index.html.erb`
  - `app/assets/stylesheets/redesign.css`
  - `test/controllers/offline_shells_controller_test.rb`
  - `test/controllers/offline_downloads_controller_test.rb`
- **Actions:**
  - In `app/views/offline_downloads/index.html.erb`:
    - Inside `<section class="empty-state offline-downloads__empty" ...>`:
      - Add recovery container:
        ```erb
        <div class="offline-downloads__recovery" <%= "hidden" unless @offline_shell %>>
          <p class="offline-downloads__recovery-hint">Disconnected from your media server. Connect to your home network or VPN to stream music.</p>
          <button type="button" class="redesign-button redesign-button--primary offline-downloads__retry-button" data-offline-connection-target="retry" data-action="click->offline-connection#check">
            <%= lucide_icon "refresh-cw", aria: { hidden: true } %>
            <span>Retry connection</span>
          </button>
        </div>
        ```
  - In `app/assets/stylesheets/redesign.css`:
    - Add styling under `.redesign`:
      ```css
      .redesign .offline-downloads__recovery {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 16px;
        margin-top: 24px;
        max-width: 360px;
      }
      .redesign .offline-downloads__recovery-hint {
        color: var(--rz-muted);
        font-size: 13px;
        line-height: 1.5;
        text-align: center;
      }
      .redesign .offline-downloads__retry-button {
        min-height: 44px;
        padding: 0 24px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        border-radius: 999px;
        background: var(--rz-primary);
        color: #fff;
        font-weight: 700;
        font-size: 14px;
      }
      .redesign .offline-downloads__retry-button:hover {
        background: #6c47f7;
      }
      ```
  - In `test/controllers/offline_shells_controller_test.rb`:
    - Assert that `.offline-downloads__recovery` is rendered without `hidden` attribute and contains `button[data-offline-connection-target='retry']`.
- **Verification:** `bin/rails test test/controllers/offline_shells_controller_test.rb test/controllers/offline_downloads_controller_test.rb` passes.

### U6. Multimodal Visual Verification and Quality Gate
- **Files:**
  - Automated test runs and screenshot capture scripts.
- **Actions:**
  - Run `npm run test:javascript`.
  - Run `bin/rails test`.
  - Capture desktop (`1440x900`) and mobile (`390x844`) screenshots of the offline downloads page and the inline service worker recovery UI.
  - Inspect screenshots with `read_file` to verify zero container clipping, >=44px touch targets, and dark theme consistency.
  - Run `bin/quality`.
- **Verification:** `bin/quality` exits 0 with zero RuboCop offenses, 100% test passes.

## Verification Contract

- **Vitest Suite:** `npm run test:javascript`
- **Rails Test Suite:** `bin/rails test`
- **Quality Gate:** `bin/quality`
- **Visual Checks:** Inspect captured desktop and mobile screenshots using `read_file`.

## Definition of Done

- [ ] `public/service-worker.js` returns an inline HTML recovery UI (HTTP 503, `text/html; charset=utf-8`) on navigation cache miss; raw `text/plain` is never returned.
- [ ] Cache keys in `app/javascript/offline_media_store.js` and `public/service-worker.js` match (`sonzra-offline-shell-v3`, `sonzra-offline-assets-v2`).
- [ ] Stale cache keys are pruned on service worker activate.
- [ ] `offline_media_controller.js` warms offline shell for all authenticated sessions regardless of download count.
- [ ] `offline_connection_controller.js` triggers connectivity checks on `visibilitychange` and `focus`, syncing all status and retry targets.
- [ ] `app/views/offline_downloads/index.html.erb` displays a prominent recovery card and retry button when 0 downloads are present in offline shell mode.
- [ ] All unit and controller tests pass.
- [ ] Desktop and mobile screenshots verified visually.
- [ ] `bin/quality` exits 0.
