# Product Requirement Document (PRD)

**Feature / Epic:** Epic 3 - Collaborative Playlist Management UI & Real-Time Live Sync  
**Issue:** [#41 - [Feature]: Collaborative Shared Playlists with Jellyfin Integration](https://github.com/sonzra/sonzra/issues/41)  
**Roadmap Reference:** [`specs/41/roadmap.md`](file:///root/Projects/sonzra/.worktrees/feat-41-collaborative-playlists/specs/41/roadmap.md)  
**Status:** Approved (Ready for Implementation)  
**Confidence Score:** 95% (Target: >90%)  
**Last Updated:** 2026-11-11  

> [!IMPORTANT]
> **Strict Product Scope:** This document defines **what** the product must do and **how it behaves for the user**, not technical implementation details. It intentionally excludes code snippets, database schemas, class/method names, or low-level technical architecture.

---

## 1. Problem Statement & User Value

### Background & Context
Music curation is inherently collaborative. Friends, partners, and roommates often build shared collections for parties, road trips, or work sessions. Currently, Sonzra playlists are strictly personal. Even though the underlying Jellyfin media server supports playlist co-curation, Sonzra listeners cannot see who shares access, invite other listeners on the instance, or see live additions and deletions as other collaborators modify the playlist in real time.

### User Persona & User Journey
- **Target Persona:** Collaborative Curator — A music fan who loves building shared mixtapes with friends or family on their home media server.
- **Primary User Journey:**
  1. The listener navigates to one of their personal playlists.
  2. In the playlist header options, they see a "Share Playlist" action (available when connected to a collaborative-capable media server like Jellyfin).
  3. Clicking "Share Playlist" opens a dedicated modal dialog showing a list of fellow instance users who share this media server.
  4. The owner selects a collaborator and toggles sharing.
  5. The invited collaborator receives a notification in their topbar drawer.
  6. When the invited collaborator opens the playlist and adds a track, the owner (and any other collaborator viewing the playlist) sees the new track appear smoothly in real time without refreshing the page or interrupting any song currently playing.
  7. When a track is removed by any collaborator, the track smoothly disappears from the list for all viewing collaborators.

### Success Metrics
- 100% real-time reflection of track additions and deletions across active collaborator screens.
- Zero audio playback interruptions or stutter during live track synchronization.
- Seamless co-ownership visibility via collaborator avatar badges in the playlist hero header.

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-1: Playlist Collaborator Visibility**
  - **Description:** Playlists with multiple collaborators display collaborator badge avatars/pills in the playlist header metadata.
  - **Observable Acceptance Criteria:**
    - Given a shared playlist, the detail hero displays collaborator indicators (e.g. "Curated with Alex, Morgan").
    - Given a personal (unshared) playlist, no collaborator badges are shown.
- **FR-2: "Share Playlist" Action & Access Control**
  - **Description:** An explicit "Share playlist" option is available in the playlist options menu for owners when the media provider supports collaborative playlists.
  - **Observable Acceptance Criteria:**
    - Given a Jellyfin connection with playlist ownership, "Share playlist" appears in the playlist header options menu.
    - Given a Plex connection (which does not support native collaborative playlists), the "Share playlist" option is gracefully omitted without breaking any other playlist features.
- **FR-3: Collaborative Sharing Dialog**
  - **Description:** A dedicated modal dialog allows the owner to manage collaborators.
  - **Observable Acceptance Criteria:**
    - The dialog lists only users registered on the Sonzra instance who connect to the same Jellyfin media server.
    - Each user row displays the user's name/email and a toggle button to add or revoke co-ownership.
    - Adding a user grants collaborator status and triggers an in-app notification in their drawer.
    - Revoking removes collaborator access immediately.
- **FR-4: Real-Time Live Sync of Track Additions**
  - **Description:** When any collaborator adds a track to a shared playlist, all other collaborators currently looking at that playlist see the new track row inserted live.
  - **Observable Acceptance Criteria:**
    - Given User A and User B both have Playlist X open.
    - When User A adds Track Z to Playlist X.
    - Then Track Z appears immediately in User B's track list without a full page refresh.
    - Background audio playing on either user's device continues uninterrupted.
- **FR-5: Real-Time Live Sync of Track Removals**
  - **Description:** When any collaborator removes a track from a shared playlist, that track row is removed live from the view for all viewing collaborators.
  - **Observable Acceptance Criteria:**
    - When User A removes Track Z from Playlist X.
    - Then Track Z disappears smoothly from User B's track list without refreshing or interrupting playback.

### Edge Cases & Handling
- **EC-1 (Collaborator Removes Currently Playing Song):** If a collaborator deletes Track Z while User B is currently listening to Track Z, the audio track continues playing to its end in User B's player, but the row is removed from the visible playlist view.
- **EC-2 (Concurrent Additions):** If two collaborators add tracks simultaneously, both tracks append cleanly in order of arrival.
- **EC-3 (Revoked Access While Viewing):** If an owner revokes User B's collaboration access while User B has the playlist open, User B can finish their current session, but subsequent attempts to mutate the playlist show a friendly permission notice (*"You no longer have permission to edit this playlist"*).

### Explicit Out-of-Scope (Non-Goals)
- Shared playback queue (synchronized multi-room audio playback).
- Cross-server sharing (sharing across different physical Jellyfin instances).

---

## 3. User Experience & Behavioral Expectations

### 3.1 Interaction Model & Screen States
- **Share Dialog Design:** Adheres strictly to Sonzra's `.redesign-*-dialog` standard:
  - Uppercase `--rz-primary-light` kicker ("COLLABORATION").
  - Clear heading ("Share Playlist").
  - Clean list of eligible fellow instance listeners with toggle switches.
  - Dedicated circular close button.
- **Empty Collaborator State:** *"No collaborators yet. Invite someone to co-curate this playlist."*
- **Live Sync Transitions:** Incoming tracks animate smoothly into the list without shifting page scroll position.

### 3.2 Responsive & Multi-Device Behavior
- **Desktop (>980px):** Centered floating dialog with backdrop blur; collaborator row buttons comfortably spaced.
- **Mobile (<=700px):** Dialog adapts smoothly to mobile width ($\le 390\text{px}$) with safe-area insets; minimum 44x44px touch targets.

### 3.3 Core Product Constraints
- **Continuous Audio Playback:** Opening the share modal, adding/removing collaborators, and receiving real-time track updates must never pause, reset, or glitch active audio playback.
- **Accessibility:** Modal traps focus while open; `Esc` dismisses; live updates announce via ARIA live regions without interrupting screen readers.

---

## 4. Resolved Decisions Log

### Decision 1: Live Track Sync Mechanism
- **Resolved Date:** 2026-11-11
- **Selected Option:** Real-time push synchronization using Turbo Streams.
- **Rationale:** Delivers an instant, native app feel without polling or requiring manual page reloads.

### Decision 2: Provider Capability Gating
- **Resolved Date:** 2026-11-11
- **Selected Option:** Feature is strictly capability-gated via media server adapter capability checks.
- **Rationale:** Ensures Plex users experience no broken UI or errors, while Jellyfin users enjoy native collaborative curation.
