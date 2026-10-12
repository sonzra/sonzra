# Product Requirement Document (PRD)

**Feature / Epic:** Epic 2 - Detail Track Menus & Playlist Trigger Wiring  
**Issue:** [#4 - Add tracks to playlists](https://github.com/sonzra/sonzra/issues/4)  
**Roadmap Reference:** [`specs/4/roadmap.md`](file:///home/bruno/Projects/sonzra/specs/4/roadmap.md)  
**Status:** Approved (Ready for Implementation)  
**Confidence Score:** 100% (Target: >90%)  
**Last Updated:** 2026-10-10  

> [!IMPORTANT]
> **Strict Product Scope:** This document defines **what** the product must do and **how it behaves for the user**, not technical implementation details. It intentionally excludes code snippets, database schemas, class/method names, or low-level technical architecture.

---

## 1. Problem Statement & User Value

### Background & Context
In Sonzra, listeners frequently explore music by browsing albums and generated mixes. While listening or inspecting track lists, listeners often discover specific standout songs they want to curate into their personal playlists.
Currently, adding a track to a playlist is only possible if the track is in the active playback queue or when interacting with shelf/grid album cards (which adds the whole album). When inspecting an album track list or a recommendation mix, there is no way to add an individual track to a playlist without playing it first and digging into the queue drawer.

### User Persona & User Journey
- **Target Persona:** Music Enthusiast & Curator — A listener who actively builds themed playlists (e.g., "Late Night Chill", "Road Trip 2026") while browsing their server library or listening to curated mixes.
- **Primary User Journey:**
  1. The listener navigates to an album page or a generated mix.
  2. While browsing the track list, they identify a song they want to save.
  3. They tap or click the track's options menu (or dedicated action) on that row.
  4. They select "Add to playlist".
  5. The playlist picker modal opens, displaying their existing playlists alongside a "New playlist" creation input.
  6. The listener either selects an existing playlist or enters a new playlist name.
  7. The picker closes immediately, a subtle toast confirms the addition (e.g. "Track added to playlist"), and active music playback continues uninterrupted without any stutter or page reload.

### Success Metrics
- 100% of track rows on album details and mix details offer a direct, reachable way to add the track to a playlist.
- 0 interruptions to running audio playback during playlist browsing, selection, or creation.
- Seamless accessibility with minimum 44x44px touch targets on mobile viewports.

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-1 (Album Track Rows):** Every track row in an album track list must provide an accessible "Add to playlist" action.
- **FR-2 (Mix / Discovery Track Rows):** Every track row in a Recommendation Collection (mix) must provide an accessible "Add to playlist" action.
- **FR-3 (Playlist Picker Re-use):** Triggering "Add to playlist" must launch the existing playlist picker sheet/dialog, populated with all playlists available on the connected media server.
- **FR-4 (New Playlist Creation on the Fly):** The listener must be able to create a new playlist by typing a title directly within the picker, which immediately creates the playlist and adds the chosen track in a single step.
- **FR-5 (Visual Feedback Toast):** Upon successful addition or creation, the interface must display a transient toast notification confirming the result (e.g., *"Track added to playlist"* or *"Playlist created and track added"*) that automatically dismisses after 3 seconds, keeping the listener immersed in their listening flow without taking them away from the album.
- **FR-6 (Playback Continuity):** Opening, interacting with, or closing the playlist picker must never pause, reset, or disrupt ongoing audio playback.
- **FR-7 (Responsive Parity & Menus):** 
  - In Redesign mode: The track row overflow menu (`...`) houses "Download" and "Add to playlist" (`list-plus`).
  - In Classic mode: A dedicated "More options" (`...`) toggle houses "Download" and "Add to playlist", keeping rows clean and touch-friendly (>=44x44px targets) on all screen widths.

### Edge Cases & Handling
- **EC-1 (Network Failure or Timeout):** If the media server fails to respond when adding a track, the loader dismisses and a clear toast feedback informs the user (e.g. *"Couldn’t add this track to the playlist"*).
- **EC-2 (Duplicate Track Addition):** If the track is already in the target playlist, the upstream media server's default behavior applies without crashing the UI, providing confirmation of completion.
- **EC-3 (Rapid Consecutive Clicks):** Action buttons must disable or guard against duplicate submissions during the creation/addition cycle to prevent duplicate entries.
- **EC-4 (Empty / Zero Playlists):** If the user has no existing playlists on the server, the picker displays a clean empty state prompt inviting them to name and create their first playlist.

### Explicit Out-of-Scope (Non-Goals)
- Removing tracks from playlists outside of playlist detail views.
- Reordering playlist tracks.
- Multi-track selection checkboxes in track lists (batch selection).
- Offline playlist creation when disconnected from the media server.

---

## 3. User Experience & Behavioral Expectations

### 3.1 Interaction Model & Screen States
- **Discovery & Placement:**
  - *Redesign Mode:* Inside the track row overflow menu (`...` icon). Opening the menu reveals "Add to playlist" with a clean icon (`list-plus`) alongside "Download".
  - *Classic Mode:* Inside a compact track row options menu toggle (`...`) alongside "Download".
- **Empty / Inactive State:** Track options remain cleanly aligned. In desktop redesign mode, the `...` menu toggle remains visible or subtle until hovered/focused.
- **Active / Picker Open State:** The background is darkened with a soft backdrop blur. A dialog or mobile bottom sheet appears with existing playlists in an alphabetically sorted or server-sorted list, plus an inline creation text field and "Create" button.
- **Completion State:** The dialog smoothly animates closed, returning focus to the triggering element. A transient pill toast displays the success message for 3 seconds.
- **Error State:** If the server rejects the request, an inline feedback message or toast alerts the user, and the sheet remains dismissible without freezing.

### 3.2 Responsive & Multi-Device Behavior
- **Desktop Experience (>980px):**
  - Menu displays as an anchored floating dropdown panel below the track's `...` button.
  - Playlist picker appears as a centered modal dialog with soft backdrop blur.
  - Escape key dismisses the dropdown and modal with immediate focus restoration.
- **Tablet Experience (701–980px):**
  - Similar to desktop, maintaining touch targets of at least 44x44px.
- **Mobile Experience (<=700px):**
  - Track row actions feature a generous touch target.
  - Playlist picker displays as an ergonomic bottom sheet adhering to `env(safe-area-inset-bottom)` with smooth slide-up animation.

### 3.3 Core Product Constraints
- **Continuous Playback:** Persistent player bar and queue must stay completely intact during all playlist actions.
- **Accessibility:** Full keyboard navigability (Tab, Enter, Escape), ARIA dialog attributes, and high contrast focus indicators.

---

## 4. Open Questions & Advisor Consultation

*(All open questions have been resolved and moved to the Resolved Decisions Log below.)*

---

## 5. Resolved Decisions Log

### Decision 1: Placement of "Add to playlist" in Classic Mode Track Lists
- **Resolved Date:** 2026-10-10
- **Selected Option:** In Classic mode, add a dedicated "More options" (`...`) toggle on track rows that houses "Download" and "Add to playlist", keeping rows clean and touch-friendly on all screen widths.
- **Rationale & Advisor Alignment:** Aligns with UI/UX guidance avoiding row overcrowding on mobile devices while maintaining 44x44px touch ergonomics and parity between Classic and Redesign interfaces.
- **Impact on Requirements:** Updated FR-7 and Section 3.1 to incorporate the overflow toggle for Classic mode.

### Decision 2: Immediate Feedback vs. "View Playlist" Action
- **Resolved Date:** 2026-10-10
- **Selected Option:** Show a transient toast notification (e.g. *"Track added to playlist"*) that auto-dismisses after 3 seconds, keeping the listener immersed in their current album or mix.
- **Rationale & Advisor Alignment:** Preserves the focused, calm listening room experience by confirming the save without intrusively redirecting or pulling the listener away from their album exploration.
- **Impact on Requirements:** Formalized in FR-5 and Section 3.1.

---

## 6. Implementation Confidence Assessment

| Confidence Dimension | Weight | Current Score | Notes |
|---|---|---|---|
| **Domain & User Journey Clarity** | 25% | 25% | User personas, motivations, and discovery journeys are fully detailed. |
| **Functional Requirements & Edge Cases** | 25% | 25% | Requirements FR-1 through FR-7 and edge cases EC-1 through EC-4 defined. |
| **UX Behavior & Ergonomic Expectations** | 25% | 25% | Redesign states, classic overflow toggles, and mobile bottom sheet behavior established. |
| **Unresolved Ambiguities (Open Questions)** | 25% | 25% | 0 open questions remaining (all reconciled in Decisions Log). |
| **Total Confidence Score** | **100%** | **100%** | **Status: Approved (Ready for Implementation)** |

> **Threshold to Proceed:** Implementation may begin only when **0 open questions remain** and the **Confidence Score is > 90%**.
