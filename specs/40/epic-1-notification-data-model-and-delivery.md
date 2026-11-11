# Product Requirement Document (PRD)

**Feature / Epic:** Epic 1 - Notification Data Model, ActionCable Stream & Delivery Service  
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
Sonzra instances support multi-user environments, allowing households, teams, and friend groups to share music infrastructure. However, listeners exist in isolated silos: when a user discovers an exceptional track, there is no way to recommend it directly to another user on the instance or notify them of shared music.

Additionally, Sonzra lacks any unified notification mechanism. Establishing a reliable, real-time notification delivery pipeline enables track sharing today and unlocks future collaborative activities (shared playlists, system alerts, server announcements).

### User Personas & User Journey
- **Persona:** Sarah (Active Sharer) & Alex (Recipient Listener).
- **User Journey:**
  1. Sarah finds a track she wants Alex to hear.
  2. Sarah sends the recommendation with a quick note.
  3. The system immediately captures the recommendation and dispatches it in real time.
  4. Alex, who is actively listening to music in Sonzra in another browser tab or device, immediately receives the notification alert without refreshing the page or interrupting their active song.
  5. The notification state (unread vs. read) is synchronized across Alex's active sessions.

### Success Metrics
- 100% of valid track share requests are saved and delivered to the recipient.
- Real-time delivery occurs within <500ms when the recipient has an active Sonzra session open.
- Absolute isolation between users: zero cross-tenant data leakage (users can only access notifications addressed to them).

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-1.1 (Notification Record Lifecycle):** The system must persist notifications with recipient identification, optional sender identification, notification type (e.g. `track_share`), track metadata (title, artist, album, media identifier, artwork identifier), an optional sender note, and read/unread status with timestamp.
- **FR-1.2 (Real-Time Notification Dispatch):** Upon creation of a notification, if the recipient is currently connected, the notification must be broadcast in real time directly to their active session(s).
- **FR-1.3 (Notification Retrieval):** Authenticated users must be able to retrieve their notification feed, ordered reverse-chronologically (newest first), with clear distinction between unread and read items.
- **FR-1.4 (Mark Single Notification as Read):** Users must be able to mark any individual notification as read, updating its status and decrementing the unread badge counter.
- **FR-1.5 (Mark All Notifications as Read):** Users must be able to mark all unread notifications as read in a single interaction.
- **FR-1.6 (Track Share Submission):** The backend must accept track share requests containing the recipient's identifier, media track identifier, track title, artist, album, artwork reference, and optional personal note (up to 280 characters).
- **FR-1.7 (Self-Share Prevention):** The system must disallow a user from sharing a track with themselves.
- **FR-1.8 (Instance User Validation):** The system must verify that the specified recipient is an active user registered on the local Sonzra instance.

### Edge Cases & Handling
- **EC-1.1 (Offline Recipient):** If the recipient has no active browser sessions when a share is sent, the notification remains unread in the database and appears automatically the next time they open Sonzra.
- **EC-1.2 (Rapid Concurrent Shares):** If a recipient receives multiple shares in rapid succession, notifications must append/prepend cleanly in reverse chronological order without dropping items or miscalculating unread counters.
- **EC-1.3 (Blank or Excessive Sender Note):** If the sender includes no note, the notification is created cleanly without a note bubble. If the note exceeds 280 characters, it is rejected with a validation message.
- **EC-1.4 (Deleted or Inactive Sender):** If a user who previously sent a track share is deleted from the instance, the notification remains legible to the recipient with appropriate fallback attribution (e.g., "Former listener").

### Explicit Out-of-Scope (Non-Goals)
- Email, Web Push (VAPID), or external device notifications.
- Editing or unsending a recommendation after delivery.
- Blocking or muting specific users on the instance (deferred to multi-user administration phase).

---

## 3. User Experience & Behavioral Expectations

### Screen States
- **Empty State:** When a user has zero notifications, a quiet, inviting empty state is presented ("No notifications yet").
- **Unread Item State:** Displays with high visual prominence, subtle background accent, and unread indicator dot.
- **Read Item State:** Displays with muted styling, retaining full access to metadata and playback actions.
- **Submitting State:** Track share submission provides immediate optimistic confirmation.

### Accessibility & Performance
- Real-time updates must not steal focus or disrupt assistive screen readers abruptly.
- Unread count changes must announce politely via status regions.

---

## 4. Resolved Decisions Log

### Decision 1: Notification Model Extensibility
- **Decision:** Use a single, extensible `Notification` foundation with structured track attributes rather than an isolated, track-share-only model.
- **Rationale:** Future milestones will introduce system notifications, server maintenance warnings, and collaborative playlist invites. A unified model avoids redundant notification infrastructure.

### Decision 2: Delivery Channel Scoping
- **Decision:** Scope real-time streams strictly to authenticated user channels.
- **Rationale:** Guarantees strict multi-tenant privacy so no listener can intercept broadcasts addressed to another user.
