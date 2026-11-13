# Product Requirement Document (PRD)

**Feature / Epic:** Epic 3 - Topbar Notification Hub & Instant Playback Integration  
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
When a user receives a track recommendation from a fellow listener, they need an immediate, prominent, yet non-intrusive way to discover it. Furthermore, the core delight of receiving a song recommendation is being able to listen to it immediately.

Currently, Sonzra has no notification center, no unread indicator in the header, and no way to start playing recommended tracks with one tap.

### User Persona & User Journey
- **Persona:** Alex (Recipient Listener).
- **User Journey:**
  1. Alex is listening to an ambient album in Sonzra while working.
  2. A subtle unread badge animates onto the topbar bell icon: "1".
  3. Alex clicks or taps the bell icon.
  4. The Notification Hub expands cleanly as a floating popover (desktop) or slide-over drawer (mobile).
  5. Alex sees:
     - Header: "Notifications" with "Mark all as read" button.
     - Card: Sarah shared "Midnight City" by M83, 2 minutes ago.
     - Sarah's note: *"Turn the volume up for the outro!"*
     - High-res track artwork thumbnail.
     - A prominent, accessible "Play" button and secondary "Add to queue" button.
  6. Alex taps "Play".
  7. The track immediately replaces the active playback queue and begins playing through Sonzra's persistent audio player.
  8. The notification automatically marks itself as read, and the unread badge clears.

### Success Metrics
- 1-click playback: Tapping play on any recommendation starts immediate audio playback in <300ms.
- 0 full page reloads: real-time notification arrival, unread state changes, and playback start happen entirely in-place.
- 100% responsive ergonomics across desktop (>980px), tablet (701–980px), and mobile ($\le 700\text{px}$).

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-3.1 (Topbar Bell Trigger):** The main navigation header must display an accessible notification bell icon button (`lucide_icon "bell"`).
- **FR-3.2 (Dynamic Unread Badge):** When the user has unread notifications, the bell displays an unread count badge pill (e.g. "1", "3", "9+"). When unread count is 0, the badge is visually hidden.
- **FR-3.3 (Notification Hub Panel):** Clicking the bell toggles open/close a notifications panel:
  - Anchored dropdown popover on desktop viewports.
  - Full-screen or bottom slide-over drawer on mobile viewports.
- **FR-3.4 (Real-Time Notification Injection):** When a new share arrives over the real-time stream:
  - The unread badge updates immediately.
  - The new notification card smoothly prepends to the top of the open panel.
  - An subtle entry animation alerts the user without disrupting active playback.
- **FR-3.5 (Notification Card Layout):**
  - Sender avatar and username attribution.
  - Relative timestamp ("just now", "5m ago", "2h ago").
  - Sender note highlighted in an accent quote bubble.
  - Track artwork thumbnail ($48\times 48\text{px}$).
  - Track title with ellipsis truncation (guaranteeing $\ge 180\text{px}$ usable width) and artist name.
  - Quick action buttons: **Play Now** (primary), **Add to Queue** (secondary), and **Mark Read** toggle.
- **FR-3.6 (Instant Playback Integration):**
  - Tapping "Play Now" starts the track immediately in the persistent player.
  - Tapping "Add to Queue" appends the track to the end of the current playback queue with a toast confirmation ("Track added to queue").
  - Triggering playback automatically transitions the notification to read state.
- **FR-3.7 (Mark All as Read Action):** A top-level action in the hub panel allowing the user to mark all unread notifications as read with one click.
- **FR-3.8 (Empty State):** When no notifications exist, display a clean, encouraging placeholder: *"No notifications yet. When friends share tracks, they’ll show up here."*

### Edge Cases & Handling
- **EC-3.1 (Outside Click / Escape):** Clicking outside the panel or pressing Escape closes the hub without changing notification state.
- **EC-3.2 (Multiple Incoming Shares in Rapid Succession):** Real-time stream dynamically updates badge count and stacks incoming cards in reverse chronological order without UI jitter.
- **EC-3.3 (Media Server Mismatch):** If the recipient has multiple server connections, playback resolves against the server connection sharing the media server where the track resides, or falls back to their preferred active server connection.

### Explicit Out-of-Scope (Non-Goals)
- Notification sound effects or browser desktop push notifications.
- Filtering notifications by type (only track shares exist in this phase).
- Permanent deletion of notification history (notifications remain in read state).

---

## 3. User Experience & Behavioral Expectations

### Geometry & Responsive Ergonomics
- **Desktop (>980px):** Dropdown popover width: 400px; max-height: 520px with smooth internal scrollbar.
- **Mobile ($\le 700\text{px}$):** Slide-up bottom sheet or full-width drawer adhering to `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)`.
- **Touch Targets:** All interactive triggers (Play, Queue, Mark read, Bell button) maintain $\ge 44\times 44\text{px}$ hitboxes.
- **Accessibility:** Hub panel includes `role="region"`, `aria-label="Notifications"`, and `aria-live="polite"` status announcements for incoming notifications.

---

## 4. Resolved Decisions Log

### Decision 1: Immediate Playback vs. Queue Insertion
- **Decision:** Provide both a primary "Play Now" button (replaces queue and plays immediately) and a secondary "Add to Queue" button.
- **Rationale:** Listeners often want to hear a recommendation right away, but sometimes prefer queueing it for later without stopping their current album.

### Decision 2: Automatic Read on Play
- **Decision:** Clicking "Play" or "Add to Queue" automatically marks the notification as read.
- **Rationale:** Prevents annoying friction where a user listens to a shared song but still has to manually click a checkmark to dismiss the unread badge.
