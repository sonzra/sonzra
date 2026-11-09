---
artifact_contract: ce-unified-plan/v1
product_contract_source: github-issue-20
execution: code
---

# Plan: Fix Background Queue Auto-Advance on iOS PWA After Long Pause

## Goal Capsule

- **Objective:** Enable reliable, seamless background queue advancement on iOS PWA when resuming playback after an extended pause, eliminating stalls where a track plays to completion but fails to move to the next queued item.
- **Means:**
  1. Implement near-end lookahead handoff in `updateTimeline()` (~0.35s before duration while audio decoding output is active) to trigger `playNext()`.
  2. Maintain `navigator.mediaSession.playbackState = "playing"` continuity across track swaps and invoke `audioTarget.load()` when reassigning `audioTarget.src`.
  3. Gracefully catch WebKit `NotAllowedError` in `monitorPlayback()` to prevent unhandled autoplay exceptions or false playback error banners upon foreground return.
  4. Ensure `handlePause()` invokes `cancelPreload()` to immediately abort in-flight prefetch requests during pauses.
- **Authority Hierarchy:** Issue #20 requirements > Sonzra architectural guidelines (`architect-advisor`, `ui-ux-advisor`) > Existing player behavior.
- **Stop Conditions:** All 4 root causes addressed in `app/javascript/controllers/player_controller.js`, comprehensive unit tests added in `test/javascript/player_controller.test.js`, and `bin/quality` passes with 0 offenses.

---

## Product Contract

### Context & User Journey
When listening to a queue in the Sonzra PWA on iOS (Safari / WebKit WebProcess):
1. The user pauses playback (e.g. locks screen, takes a call, or steps away for minutes/hours).
2. The user resumes playback from lock screen controls, headphones, or the PWA interface.
3. The resumed track finishes playing.
4. **Current Bug:** Audio goes silent at track end. The queue fails to advance to the next track in the background. If the user returns to the app, the player may attempt autoplay without a user gesture, triggering `NotAllowedError` and getting stuck in playback recovery.
5. **Expected Behavior:** Audio transitions smoothly to the next track in the queue in the background. Media session notifications and lock screen controls stay in sync. If the device returns to the foreground, the player state is consistent and functional.

### Requirements
- **R1: Background Lookahead Advancement:** When an audio track is within 0.35s of completion during active background decoding, the player must initiate queue advancement before CoreAudio output reaches zero and WebKit suspends the WebProcess.
- **R2: MediaSession & Pipeline Continuity:** During track transition (`loadTrack` / `playCurrent`), `navigator.mediaSession.playbackState` must remain `"playing"` (when `playbackRequested` is true) and `audioTarget.load()` must be invoked to initialize the new media stream in WebKit.
- **R3: Non-Disruptive Autoplay Handling:** Catch `NotAllowedError` and `AbortError` in `monitorPlayback()`. In the event of a browser autoplay rejection on foreground return or background pause, transition gracefully to the paused state instead of triggering false error alerts ("This track could not be played") or retry loops.
- **R4: Pause Preload Invalidation:** Whenever playback is paused (`handlePause()`), cancel any active stream preloading fetch (`cancelPreload()`) to conserve network and prevent background worker contention.

---

## Planning Contract

### Architectural Analysis & Boundary Verification
- **Hexagonal Boundary:** All modifications are isolated to the Hotwire/Stimulus layer (`player_controller.js`) and its DOM/MediaSession bindings. No backend service objects or server integration adapters are affected.
- **Persistent Player & Hotwire Invariant:** The player shell retains `data-turbo-permanent` and preserves its existing reactive UI bindings, tab navigation, and sleep timer integrations.
- **UI & UX Constraints:** The 3-row layout (Identity, Scrubber, Transport) and 44x44px touch targets are unaffected. Play/pause button icons and ARIA attributes remain strictly synchronized.

### Technical Design

#### 1. Lookahead Threshold Handoff
- Define `const BACKGROUND_HANDOFF_THRESHOLD = 0.35` in `player_controller.js`.
- In `updateTimeline()`:
  ```javascript
  const hasRemainingBuffer = Number.isFinite(duration) && duration > 0
  const isNearEnd = hasRemainingBuffer && (duration - this.audioTarget.currentTime) <= BACKGROUND_HANDOFF_THRESHOLD
  const shouldAdvanceInLookahead = isNearEnd && !this.audioTarget.paused && !this.advancingQueue

  if (shouldAdvanceInLookahead) {
    const hasNextTrack = this.repeatMode === "one" ||
                         this.repeatMode === "all" ||
                         this.currentIndex < this.queue.length - 1 ||
                         this.radioEnabled ||
                         (this.shuffleMode && this.shuffledIndices?.length > 0)
    if (hasNextTrack) {
      this.playNext()
      return
    }
  }
  ```
- In `reconcilePlayback()`:
  Update the finish condition to check `this.audioTarget.ended || (Number.isFinite(duration) && duration > 0 && this.audioTarget.currentTime >= duration - BACKGROUND_HANDOFF_THRESHOLD)` when `!this.audioTarget.paused || this.audioTarget.ended || this.playbackRequested`.

#### 2. MediaSession Continuity & WebKit `load()`
- In `loadTrack(track, ...)`:
  ```javascript
  this.audioTarget.src = track.source
  if (typeof this.audioTarget.load === "function") {
    this.audioTarget.load()
  }
  ```
- In `syncBrowserMedia()`:
  ```javascript
  mediaSession.playbackState = (this.playbackRequested || !this.audioTarget?.paused) ? "playing" : "paused"
  ```
- In `playCurrent()`:
  Ensure `navigator.mediaSession.playbackState = "playing"` is asserted before calling `this.audioTarget.play()`.

#### 3. Graceful Autoplay Rejection Handling
- In `monitorPlayback(playback)`:
  ```javascript
  playback.then(() => {
    if (!this.progressWatch) this.handlePlay()
  }).catch((error) => {
    if (error?.name === "NotAllowedError") {
      this.playbackRequested = false
      this.clearPlaybackRecovery()
      this.handlePause()
      return
    }
    if (error?.name === "AbortError") {
      return
    }
    this.handlePlaybackError()
  })
  ```

#### 4. Preload Cleanup on Pause
- In `handlePause()`:
  Add `this.cancelPreload()` at the start of `handlePause()`.

---

## Implementation Units

### Unit U1: Preload Cancellation on Pause
- **Target File:** `app/javascript/controllers/player_controller.js`
- **Scope:**
  - Call `this.cancelPreload()` inside `handlePause()`.
- **Verification:** Unit test asserting `preloadAbortController.abort()` is called when `handlePause()` triggers.

### Unit U2: MediaSession Continuity & `audioTarget.load()` Call
- **Target File:** `app/javascript/controllers/player_controller.js`
- **Scope:**
  - Call `this.audioTarget.load?.()` after updating `this.audioTarget.src` in `loadTrack()`.
  - Update `syncBrowserMedia()` and `playCurrent()` so `navigator.mediaSession.playbackState` stays `"playing"` across track transition.
- **Verification:** Unit test verifying `audioTarget.load()` is called on new track load and `mediaSession.playbackState` remains `"playing"`.

### Unit U3: Near-End Lookahead Advancement in `updateTimeline()` & `reconcilePlayback()`
- **Target File:** `app/javascript/controllers/player_controller.js`
- **Scope:**
  - Add constant `BACKGROUND_HANDOFF_THRESHOLD = 0.35`.
  - In `updateTimeline()`, trigger `playNext()` if `!audioTarget.paused && !advancingQueue && (duration - currentTime) <= BACKGROUND_HANDOFF_THRESHOLD` and a next track is available.
  - In `reconcilePlayback()`, check boundary against `BACKGROUND_HANDOFF_THRESHOLD`.
- **Verification:** Unit test simulating `timeupdate` at `duration - 0.25s` triggers `playNext()` without waiting for `ended` or interval timer.

### Unit U4: Safe Autoplay Catch-Up in `monitorPlayback()`
- **Target File:** `app/javascript/controllers/player_controller.js`
- **Scope:**
  - In `monitorPlayback()`, inspect caught errors.
  - If `NotAllowedError`, clear recovery timeout, set `playbackRequested = false`, and call `handlePause()`.
  - If `AbortError`, silently return.
  - Otherwise, delegate to `handlePlaybackError()`.
- **Verification:** Unit test verifying a rejected `play()` promise with `NotAllowedError` sets toggle to play and avoids setting error text or triggering recovery retry.

### Unit U5: Full Vitest Regression Suite & Quality Gates
- **Target File:** `test/javascript/player_controller.test.js`
- **Scope:**
  - Add comprehensive test cases covering U1-U4.
  - Run `npm run test:javascript`.
  - Run `bin/quality`.
- **Verification:** All tests green, zero lint offenses.

---

## Verification Contract

### Automated Quality Commands
- JavaScript suite: `npm run test:javascript`
- Linting suite: `bundle exec rubocop`
- Full quality gate: `bin/quality`

### Success Criteria
1. `npm run test:javascript` passes with 100% test pass rate including new iOS background advance tests.
2. `bin/quality` exits with code 0 and 0 offenses.
3. No regressions in existing queue, radio, sleep timer, or offline playback features.

---

## Definition of Done
- [ ] Isolated worktree `.worktrees/fix-ios-queue-advance` is active.
- [ ] Near-end lookahead handoff in `updateTimeline()` triggers `playNext()` at `duration - currentTime <= 0.35s`.
- [ ] `audioTarget.load()` is invoked when reassigning `src`.
- [ ] `navigator.mediaSession.playbackState` remains `"playing"` during queue track transitions.
- [ ] `monitorPlayback()` gracefully catches `NotAllowedError` and `AbortError`.
- [ ] `handlePause()` calls `cancelPreload()`.
- [ ] Vitest unit tests added and passing in `test/javascript/player_controller.test.js`.
- [ ] `bin/quality` passes with 0 offenses.
