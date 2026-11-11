# Product Requirement Document (PRD)

**Feature / Epic:** Epic 2 - Context Menu Share Actions & Recipient Picker Dialog  
**Issue:** [#40 - Direct Track Sharing & In-App Notification System](https://github.com/sonzra/sonzra/issues/40)  
**Roadmap Reference:** [`specs/40/roadmap.md`](file:///root/Projects/sonzra/.worktrees/feat-40-track-sharing-notifications/specs/40/roadmap.md)  
**Status:** Approved (Ready for Technical Specification)  
**Confidence Score:** 100%  
**Last Updated:** 2026-11-11  

> [!IMPORTANT]
> **Strict Product Scope:** This document defines **what** the product must do and **how it behaves for the user**, not technical implementation details. It intentionally excludes code snippets, database schemas, class/method names, or low-level technical architecture.

---

## 1. Problem Statement & User Value

### Background & Context
Music discovery is inherently social. When listeners encounter a captivating song while listening to an album, browsing search results, inspecting an artist's catalog, or listening to the active queue, they want an immediate, frictionless path to share that song with a fellow listener without breaking away from their listening session.

Currently, Sonzra's context menus only allow queueing, favoriting, or adding to playlists. There is no sharing trigger, and no dialog to select recipients.

### User Persona & User Journey
- **Persona:** Marcus — Listening to music on mobile or desktop while working.
- **User Journey:**
  1. While listening or browsing an album, Marcus hears or spots a great song.
  2. Marcus taps the track's overflow options menu (or long-presses on mobile).
  3. Marcus selects the new "Share track" option.
  4. The Recipient Picker dialog opens as a centered modal (desktop) or smooth bottom sheet (mobile), showing:
     - A compact track preview card (artwork thumbnail, title, artist).
     - A list of other registered listeners on the Sonzra instance with instant search filtering.
     - An optional text field to write a recommendation note (e.g. *"Check out the guitar solo at 2:15!"*).
  5. Marcus selects Sarah and taps "Send".
  6. The dialog closes smoothly, a toast confirms "Track shared with Sarah", and active music playback continues without interruption.

### Success Metrics
- Reached from all primary audio touchpoints: Persistent Player, Playback Queue, Album Track Lists, Artist Discographies, and Search Results.
- 0 interruptions to running audio playback during the share flow.
- Touch target ergonomics $\ge 44\times 44\text{px}$ across all mobile interactive surfaces.

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-2.1 (Share Trigger in Card Options Sheet):** The centralized card options sheet must include a "Share track" action (icon: `share-2`) for all audio items.
- **FR-2.2 (Share Trigger in Detail Track Menus):** Track row overflow menus across album and mix views must offer the "Share track" action.
- **FR-2.3 (Share Trigger in Persistent Player & Queue):** The persistent audio player's track info and the playback queue row options must provide access to "Share track".
- **FR-2.4 (Track Preview Chip in Dialog):** Opening the share dialog must display the active track's artwork thumbnail, title, and artist name for clear visual confirmation of what is being shared.
- **FR-2.5 (Recipient Selection):** The dialog must list all registered users on the local instance (excluding the current user), with user avatars/initials and identifiers.
- **FR-2.6 (Recipient Search / Filter):** For instances with multiple users, an inline search input must filter the recipient list dynamically as the user types.
- **FR-2.7 (Optional Sender Note):** An accessible multi-line text input allowing an optional note (up to 280 characters) with live character counter.
- **FR-2.8 (Submit & Loading Feedback):** Tapping "Send recommendation" disables duplicate clicks, shows a loading indicator, dismisses the modal upon success, and displays a transient confirmation toast ("Track shared with [Name]").
- **FR-2.9 (Playback Continuity Guarantee):** Opening, interacting with, typing inside, or dismissing the share dialog must never pause, reset, or stutter ongoing audio playback.

### Edge Cases & Handling
- **EC-2.1 (Single User on Instance):** If the current user is the sole registered user on the Sonzra instance, the dialog presents a helpful state: *"No other listeners registered on this instance yet. Invite users in Administration to start sharing music."*
- **EC-2.2 (Network Error on Submission):** If the server fails to record the share, the modal remains open, displays an inline error message ("Couldn’t send recommendation right now"), and allows retrying without losing the entered note.
- **EC-2.3 (Modal Dismissal):** The user can cancel and close the modal at any time via Escape key, clicking the backdrop, or tapping the "✕" close button.

### Explicit Out-of-Scope (Non-Goals)
- Group sharing (sharing to multiple recipients simultaneously in one action — single recipient per share).
- Sharing entire albums, playlists, or mixes (single audio track sharing only in this phase).
- Generating public web share links or social media sharing (instance-internal sharing only).

---

## 3. User Experience & Behavioral Expectations

### Interaction Model & Screen States
- **Trigger Presentation:** Clean typography with `lucide_icon "share-2"`, matching existing action menu styles.
- **Dialog Geometry:**
  - *Desktop (>980px):* Centered modal dialog, max-width 480px, soft backdrop blur (`backdrop-filter: blur(12px)`), keyboard focus trapped inside modal.
  - *Mobile ($\le 700\text{px}$):* Slide-up bottom sheet pinned to screen bottom, adhering to `env(safe-area-inset-bottom)`.
- **Keyboard & a11y Navigation:**
  - `Escape` closes the dialog and restores focus to the trigger button.
  - Form controls have explicit `aria-label`s and visible focus rings.

---

## 4. Resolved Decisions Log

### Decision 1: Modal Pattern
- **Decision:** Use native `<dialog class="redesign-share-dialog">` rendered once in the application layout shell, manipulated via Stimulus.
- **Rationale:** Aligns with Sonzra's canonical modal architecture (`.redesign-search-dialog`, `.playlist-picker`). Prevents DOM duplication across every track row.

### Decision 2: Instant Feedback
- **Decision:** Use Sonzra's existing persistent player toast system (`player#showFeedback`) for confirmation.
- **Rationale:** Consistent user feedback language across favorites, playlist additions, and sharing.
