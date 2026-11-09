---
title: "iOS PWA Background Audio Queue Advancement and WebKit Lifecycle Resilience"
date: "2026-11-09"
category: "audio-player"
module: "app/javascript/controllers/player_controller.js"
problem_type: "runtime_error"
component: "frontend"
severity: "high"
symptoms:
  - "Resuming playback after an extended pause on iOS PWA plays current track to completion then audio goes silent"
  - "Queue fails to advance to next track in the background when phone screen is locked or backgrounded"
  - "Returning to PWA foreground causes NotAllowedError autoplay rejection and enters broken playback recovery"
root_cause: "async_timing"
resolution_type: "code_fix"
tags:
  - "ios"
  - "webkit"
  - "pwa"
  - "background-audio"
  - "mediasession"
  - "coreaudio"
  - "autoplay"
---

# iOS PWA Background Audio Queue Advancement and WebKit Lifecycle Resilience

## Problem
When playing a queue in Sonzra's iOS Progressive Web App (PWA) under Safari / WebKit, pausing playback and resuming minutes or hours later (via lock screen, Bluetooth headphones, or the PWA interface) played the resumed track to completion. However, when the track ended while the phone was locked or in the background, Sonzra failed to advance automatically to the next track. The audio dropped silent, and if the user unlocked and reopened the PWA, the controller attempted to autoplay the next track without an active user gesture, triggering a browser `NotAllowedError` rejection that sent the player into an unnecessary error recovery loop.

## Symptoms
- Lock screen and headphone audio went silent when a track ended in the background following a long pause.
- The queue appeared stuck at the end of the previous track until the user manually tapped "Next" in the PWA.
- Reopening the app after background completion caused the player to display "This track could not be played. Check the server logs and try again." or loop through playback recovery attempts due to uncaught `NotAllowedError`.
- Lock screen MediaSession playback status momentarily flickered between "playing" and "paused" during track changes.

## What Didn't Work
- **Relying solely on DOM `ended` events:** In iOS WebKit (WebKit Bug 173332 / 261858), when an audio stream decodes to duration in the background, CoreAudio output drops to zero. WebKit immediately relinquishes its background process execution assertion and suspends the WebProcess before DOM `ended` event listeners can be dispatched or executed.
- **Relying on `setInterval` (`progressWatch`):** JavaScript interval timers are aggressively throttled or completely frozen by iOS WebKit when the display locks or the PWA transitions to the background. Periodic polling in `reconcilePlayback()` never fires while backgrounded.
- **Immediate `audioTarget.play()` on `visibilitychange`:** Document lifecycle and visibility events do not carry a transient user activation gesture in Safari. Calling `audio.play()` on foreground return is rejected by browser autoplay policies with `NotAllowedError`. Treating this rejection as an unhandled error triggered repeated recovery attempts and rendered an error message for an otherwise valid track.

## Solution
In PR #24, we implemented four coordinated lifecycle protections in `app/javascript/controllers/player_controller.js`:

1. **Near-End Lookahead Handoff (`updateTimeline`):**
   Defined `BACKGROUND_HANDOFF_THRESHOLD = 0.35` (seconds). In `updateTimeline()`, which continues firing on WebKit decoding updates during active playback, evaluated whether playback is within 0.35s of completion (`duration - currentTime <= 0.35s`). While audio decoding output is still active and CoreAudio assertions are held, `updateTimeline()` proactively invokes `this.playNext()`.

   ```javascript
   const BACKGROUND_HANDOFF_THRESHOLD = 0.35

   if (!this.audioTarget.paused && !this.advancingQueue && duration > 0 && (duration - this.audioTarget.currentTime) <= BACKGROUND_HANDOFF_THRESHOLD) {
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

2. **MediaSession Continuity & WebKit `load()`:**
   When reassigning `audioTarget.src`, browser media elements momentarily transition to a paused state before the next play promise settles. We maintain `navigator.mediaSession.playbackState = "playing"` whenever `playbackRequested` is true, preventing WebKit's background audio watchdog from dropping assertions. Additionally, explicitly invoked `audioTarget.load()` upon setting `src` to force WebKit to initialize the new media pipeline immediately.

   ```javascript
   this.audioTarget.src = track.source
   if (typeof this.audioTarget.load === "function") {
     this.audioTarget.load()
   }
   ```

3. **Graceful Autoplay Rejection Handling (`monitorPlayback`):**
   Updated `monitorPlayback()` to catch `NotAllowedError` and `AbortError`. If playback fails due to autoplay policy restrictions (such as returning to the foreground without a user gesture), the player clears recovery timeouts and gracefully updates transport controls to the paused state (`handlePause()`) so the track is ready to resume on the user's next tap without false error banners.

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

4. **Pause Cleanup (`handlePause`):**
   Called `this.cancelPreload()` in `handlePause()` to immediately abort in-flight fetch streams when playback pauses, preventing background worker contention.

## Why This Works
- **Preserved CoreAudio Assertions:** By advancing ~350ms prior to the final audio frame, CoreAudio continues streaming output buffers without hitting the zero-output threshold that triggers WebKit process suspension.
- **Unbroken Background State:** Maintaining `mediaSession.playbackState = "playing"` during synchronous track swaps signals to iOS that active playback has not ceased, keeping the lock screen session and background audio daemon engaged.
- **User Gesture Resiliency:** Distinguishing between genuine decoding/network failures and browser gesture-gating (`NotAllowedError`) prevents spurious error states, leaving the player clean and responsive upon resumption.

## Prevention
- **Avoid Depending on DOM `ended` or JS Timers for Background State Transitions:** In mobile web applications, timers freeze and `ended` events can be dropped. Always trigger queue handoffs slightly ahead of track completion while the audio pipeline is actively decoding.
- **Decouple MediaSession State from Ephemeral `<audio>` DOM State During Track Swaps:** When transitioning between tracks, `audio.paused` briefly evaluates to `true` between `audio.src = ...` and `audio.play()`. Do not bind `mediaSession.playbackState` strictly to `audio.paused` without accounting for `playbackRequested`.
- **Never Treat `NotAllowedError` as a Media Failure:** Autoplay rejections are policy gates, not media stream errors. Always fall back to a paused UI state awaiting a user tap rather than triggering error recovery.

## Related Issues
- GitHub Issue: [#20](https://github.com/sonzra/sonzra/issues/20)
- Pull Request: [#24](https://github.com/sonzra/sonzra/pull/24)
