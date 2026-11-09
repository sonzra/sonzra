# Plan: Fix iOS PWA Background Playback on App Switch After Long Pause

```yaml
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
```

## Goal Capsule

- **Objective**: Fix GitHub Issue #21 where resuming playback after an extended pause on iOS PWA plays in the foreground, but immediately stops when switching to another app or locking the screen.
- **Means**:
  1. Bypass `createMediaElementSource` on iOS/WebKit so `audioTarget` remains a pure native `HTMLMediaElement` (`MediaType::Audio`), allowing iOS background audio policies to govern playback while the existing CSS keyframes animate the 3-bar indicator.
  2. Re-assert `navigator.audioSession.type = "playback"` via `configureAudioSession()` on every `play()`, `toggle()`, `playCurrent()`, and `handleVisibilityChange()`.
  3. Detect resume after extended idle (>15 min) using wall-clock timestamps and reload the media element (`audioTarget.load()`) preserving `pendingStartPosition` to flush stale TCP sockets.
- **Authority & Hierarchy**:
  - `GEMINI.md`: Git worktree isolation, Hotwire persistent player integrity, zero quality gate violations (`bin/quality`).
  - `architect-advisor`: Maintain clean presentation boundaries in `PlayerController`, no SPA regressions, zero external network calls in unit tests.
  - `ui-ux-advisor`: Preserve playback visualizer continuity using CSS fallback (`redesign-playing-bar`), ensure zero layout shift or theme breakage.
- **Stop Conditions**:
  - All Vitest and Rails tests pass.
  - `bin/quality` exits 0 with zero RuboCop or lint offenses.

---

## Product Contract

### Requirements
- **R1 (iOS Web Audio Bypass)**: On iOS devices (iPhone, iPad, iPod, iPadOS touch desktop emulation), `PlayerController` must not attach `audioTarget` to an `AudioContext` via `createMediaElementSource`. The 3-bar equalizer mark must fallback to the existing CSS animation (`.redesign .listen-player.is-playing .listen-player__playing-mark:not(.is-reactive) i`).
- **R2 (AudioSession Re-assertion)**: `navigator.audioSession.type = "playback"` must be re-asserted on every resume or foreground transition (`play()`, `toggle()`, `playCurrent()`, and `handleVisibilityChange()`).
- **R3 (Stale Connection Flush)**: Resuming playback after an idle/pause duration exceeding 15 minutes (`EXTENDED_IDLE_THRESHOLD_MS = 900_000`) must call `audioTarget.load()` while preserving `pendingStartPosition = currentTime`, flushing hung TCP sockets.
- **R4 (Non-iOS Continuity)**: Non-iOS browsers (Chrome, Firefox, Safari desktop) retain reactive Web Audio visualizer functionality when supported.

### Acceptance Examples
- **AE1 (iOS Visualizer Bypass)**: With `navigator.userAgent` containing `"iPhone"`, calling `startVisualizer()` does not instantiate `createMediaElementSource`, returns `false` from `prepareVisualizer()`, and leaves the visualizer target without `.is-reactive`.
- **AE2 (AudioSession on Resume & Visibility)**: When `navigator.audioSession` is supported:
  - Invoking `toggle()` when paused sets `navigator.audioSession.type = "playback"`.
  - Invoking `playCurrent()` sets `navigator.audioSession.type = "playback"`.
  - Invoking `handleVisibilityChange()` when `document.visibilityState === "visible"` sets `navigator.audioSession.type = "playback"`.
- **AE3 (Stale Connection Recovery)**:
  - Audio is paused at `currentTime = 42`.
  - Mock clock advances by 16 minutes (`Date.now() + 16 * 60 * 1000`).
  - Calling `toggle()` to resume triggers `audioTarget.load()`, sets `controller.pendingStartPosition = 42`, and initiates `audioTarget.play()`.
- **AE4 (Short Pause No-Op)**:
  - Audio is paused at `currentTime = 42`.
  - Mock clock advances by 2 minutes.
  - Calling `toggle()` to resume does not call `audioTarget.load()`.

---

## Planning Contract

### Known Technical Decisions (KTDs)
- **KTD 1: iOS Detection Pattern**:
  Use standard WebKit/iOS detection:
  ```javascript
  isIOS() {
    const nav = typeof navigator !== "undefined" ? navigator : null
    if (!nav) return false
    return (
      /iPad|iPhone|iPod/.test(nav.userAgent || "") ||
      (nav.platform === "MacIntel" && (nav.maxTouchPoints || 0) > 1)
    )
  }
  ```
  This covers iOS Safari, iOS Chrome (`CriOS`), Firefox iOS, iOS PWA standalone mode, and iPadOS desktop user-agent strings.
- **KTD 2: Wall-Clock Idle Tracking**:
  JavaScript timers (`setInterval`, `setTimeout`) freeze when iOS suspends background PWA tabs. Wall-clock `Date.now()` is immune to timer suspension:
  - In `handlePause()`, record `this.pausedAt = Date.now()`.
  - In `handlePlay()`, clear `this.pausedAt = null`.
  - On resume (`play()`, `toggle()`), if `this.pausedAt && (Date.now() - this.pausedAt) > 15 * 60 * 1000`, invoke `this.refreshStaleConnectionIfIdle()`.
- **KTD 3: Position Preservation on `load()`**:
  Calling `audioElement.load()` resets `currentTime` to 0. `PlayerController` already features `this.pendingStartPosition` and restores it in `updateTimeline()` upon `loadedmetadata`/`canplay`/`timeupdate`. Capturing `this.pendingStartPosition = Number(this.audioTarget.currentTime) || 0` immediately before `this.audioTarget.load()` ensures seamless resume.

---

## Implementation Units

### U1: iOS Detection & Visualizer Bypass
- **Files**: `app/javascript/controllers/player_controller.js`
- **Changes**:
  - Add `isIOS()` helper method on `PlayerController`.
  - In `prepareVisualizer()`, prepend `if (this.isIOS()) return false`.
  - Preserve all existing fallback visualizer CSS styles in `app/assets/stylesheets/redesign.css`.
- **Verification**: Unit test in `test/javascript/player_controller.test.js` verifying that iOS UA bypasses `createMediaElementSource`.

### U2: AudioSession Category Re-assertion & `play()` Method
- **Files**: `app/javascript/controllers/player_controller.js`
- **Changes**:
  - Add `play()` method on `PlayerController` that asserts `this.configureAudioSession()`, checks stale connection refresh, sets `this.playbackRequested = true`, and monitors `this.audioTarget.play()`.
  - In `toggle()`, when `this.audioTarget.paused` is true, invoke `this.configureAudioSession()`.
  - In `playCurrent()`, invoke `this.configureAudioSession()`.
  - In `handleVisibilityChange()`, when `document.visibilityState !== "hidden"`, invoke `this.configureAudioSession()`.
- **Verification**: Unit test verifying `navigator.audioSession.type` is set in all 4 entry points.

### U3: Stale TCP Connection Refresh After Extended Idle
- **Files**: `app/javascript/controllers/player_controller.js`
- **Changes**:
  - Define `EXTENDED_IDLE_THRESHOLD_MS = 15 * 60 * 1000`.
  - In `connect()`, initialize `this.pausedAt = null`.
  - In `handlePause()`, set `this.pausedAt = Date.now()`.
  - In `handlePlay()`, set `this.pausedAt = null`.
  - In `clearQueue()` and `loadTrack()`, reset `this.pausedAt = null`.
  - Implement `refreshStaleConnectionIfIdle()`:
    ```javascript
    refreshStaleConnectionIfIdle() {
      if (!this.pausedAt || !this.hasAudioTarget || !this.audioTarget.src) return

      const idleDuration = Date.now() - this.pausedAt
      if (idleDuration > EXTENDED_IDLE_THRESHOLD_MS) {
        const currentPosition = Number(this.audioTarget.currentTime) || this.pendingStartPosition || 0
        this.pendingStartPosition = currentPosition
        this.audioTarget.load()
      }
      this.pausedAt = null
    }
    ```
  - Call `this.refreshStaleConnectionIfIdle()` in `toggle()` and `play()` when resuming.
- **Verification**: Unit tests covering idle >15m (triggers `load()`) and idle <15m (no `load()`).

### U4: Vitest Test Suite & Quality Gate
- **Files**: `test/javascript/player_controller.test.js`
- **Changes**:
  - Add tests for:
    - iOS UA visualizer bypass (`isIOS()` returns true -> `prepareVisualizer()` returns false -> no `is-reactive`).
    - AudioSession re-assertion on `play()`, `toggle()`, `playCurrent()`, and `handleVisibilityChange()`.
    - Extended idle stale connection reload (>15 min vs <15 min).
- **Verification**:
  - `npm run test:javascript` passes (all 174+ tests pass).
  - `bin/quality` passes.

---

## Verification Contract

- **Unit Tests**:
  - `npm run test:javascript`
- **Quality Gate**:
  - `bundle exec rubocop`
  - `bin/quality`
- **Manual / Visual Checks**:
  - Check equalizer bar animation fallback on iOS simulated user-agent.

---

## Definition of Done

- [ ] All 4 implementation units completed in worktree `.worktrees/fix-ios-background-playback`.
- [ ] iOS bypasses Web Audio graph, preventing `MediaSessionRestriction::BackgroundProcessPlaybackRestricted`.
- [ ] `navigator.audioSession.type = "playback"` is actively re-asserted on `play()`, `toggle()`, `playCurrent()`, and foreground visibility change.
- [ ] Pausing for >15 minutes flushes stale TCP sockets via `audioTarget.load()` with position preserved.
- [ ] All JavaScript unit tests pass cleanly.
- [ ] `bin/quality` exits 0.
