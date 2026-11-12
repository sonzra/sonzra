# Product Requirement Document (PRD)

**Feature / Epic:** Epic 2 - In-App Notification System & Real-Time Delivery  
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
When users on the same Sonzra instance share playlists or collaborate on collections, invited collaborators have no awareness of being invited unless told outside the app. Furthermore, as Sonzra evolves into a richer multi-user music experience, listeners need a central, quiet, and unobtrusive place to see relevant updates without being bombarded with noisy pop-ups or interrupting their listening sessions.

### User Persona & User Journey
- **Target Persona:** Social Curator & Collaborator — A listener who curates playlists with friends or household members on the same Sonzra instance and wants to know when someone shares a playlist with them.
- **Primary User Journey:**
  1. Collaborator opens Sonzra or is actively listening to music.
  2. A peer shares a collaborative playlist with them.
  3. An unread dot or badge subtly appears on the topbar notification bell icon (with zero playback stutter and no disruptive pop-up overlay).
  4. The listener clicks or taps the bell icon in the topbar.
  5. The notifications drawer slides or reveals quietly, showing the message: *"Alex shared the playlist 'Late Night Beats' with you."*
  6. Tapping the notification marks it as read and immediately navigates the listener to the shared playlist, keeping audio playing in the persistent player.
  7. The listener can dismiss or clear notifications at any time.

### Success Metrics
- 100% of playlist sharing invitations generate an in-app notification for the invited user.
- 0 interruptions to active audio playback when notifications arrive or when opening the notification panel.
- Clean notification badge clearing and read-state management.

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-1: Topbar Notification Bell Indicator**
  - **Description:** A notification bell icon resides in the topbar header action cluster.
  - **Observable Acceptance Criteria:**
    - Given a user with zero unread notifications, the bell displays in its quiet, neutral state.
    - Given a new notification arrives or exists unread, the bell displays an accent badge indicator (with count or highlight).
    - Given a user taps the bell, the notification drawer opens.
- **FR-2: In-App Notification Drawer Presentation**
  - **Description:** Per confirmed user requirement, all notifications reside strictly inside the topbar notifications drawer (no transient pop-up toasts during music playback).
  - **Observable Acceptance Criteria:**
    - Opening the drawer presents a chronological list of recent notifications with timestamps (e.g. "Just now", "2 hours ago").
    - Each item clearly displays the sender's identity, the notification title/message, and an unread status marker.
- **FR-3: Notification Action & Navigation**
  - **Description:** Clicking or tapping a notification navigates directly to the referenced playlist item.
  - **Observable Acceptance Criteria:**
    - Given a user taps a playlist invitation notification, the drawer closes, the playlist detail page loads, and active playback is preserved.
    - The tapped notification transitions visually from unread to read.
- **FR-4: Mark as Read & Dismissal**
  - **Description:** Users can mark individual notifications as read or clear them.
  - **Observable Acceptance Criteria:**
    - A "Mark all as read" control allows clearing unread status in one click.
    - Individual notifications provide a clear/dismiss action.
- **FR-5: Real-Time Drawer Delivery**
  - **Description:** While a user is actively in a session, receiving a new notification updates the bell badge and drawer content in real time without refreshing the page.

### Edge Cases & Handling
- **EC-1 (No Notifications):** If a user has no notifications, the drawer displays a tranquil empty state: *"No new notifications. Your listening room is quiet."*
- **EC-2 (Deleted Playlist):** If a shared playlist was deleted by its owner before the invited user opens the notification, clicking the notification navigates gracefully and displays a friendly error notice (*"This playlist is no longer available"*), without breaking the UI.
- **EC-3 (Network Interruption):** If the network drops while opening or clearing notifications, optimistic UI state holds, or an unobtrusive offline notice indicates the connection state.

### Explicit Out-of-Scope (Non-Goals)
- Email or push notifications (APNs / Web Push) — strictly focused on self-hosted in-app notifications.
- Toast banners that pop over active album art or scrubber controls.

---

## 3. User Experience & Behavioral Expectations

### 3.1 Interaction Model & Screen States
- **Discovery & Placement:** The notification bell is positioned in `.redesign-topbar__actions` between the search trigger and the user profile menu.
- **Empty State:** Neutral bell with no badge; empty drawer displays an atmospheric illustration or quiet text.
- **Unread Active State:** Bell shows an illuminated accent dot (`--rz-accent`).
- **Drawer Open State:** Desktop shows a sleek anchored popover dropdown (`--rz-raised` surface, blur, hairline border); mobile shows a comfortable sliding panel or top-anchored drawer.
- **Touch Ergonomics:** Bell trigger and notification items have $\ge 44\times 44\text{px}$ touch targets.

### 3.2 Responsive & Multi-Device Behavior
- **Desktop (>980px):** Dropdown anchored to the topbar with keyboard navigation (`Esc` dismisses, focus-visible outlines intact).
- **Mobile (<=700px):** Drawer is full-width or slide-down, respecting mobile safe areas (`env(safe-area-inset-top)`).

### 3.3 Core Product Constraints
- **Continuous Audio Playback:** Opening, reading, and clearing notifications must never pause, reset, or glitch active audio playback.
- **Accessibility:** Bell has `aria-label="Notifications"`, unread count announced to assistive technologies via `aria-live="polite"`.

---

## 4. Resolved Decisions Log

### Decision 1: Notification Channel Placement
- **Resolved Date:** 2026-11-11
- **Selected Option:** Strictly inside the topbar drawer (no transient pop-up toasts across active playback).
- **Rationale:** Preserves the "quiet listening room" ethos, preventing visual noise and focus theft while listening to music.

### Decision 2: Target Audience for Shared Playlists
- **Resolved Date:** 2026-11-11
- **Selected Option:** Restricted to Sonzra users on the same instance connected to the same Jellyfin media server.
- **Rationale:** Guarantees privacy, prevents leaking usernames across unrelated instances or servers, and ensures in-app notifications can be delivered.
