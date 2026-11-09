# Product Requirement Document (PRD)

**Feature / Epic:** Epic 3 - Detail Hero Actions & Discography/Mix Playlist Integration  
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
When exploring a favorite artist's profile, a classic album, or a freshly generated mix, listeners often want to save the entire collection in bulk rather than manually adding songs one by one.
While Sonzra permits adding an entire album from shelf/grid cards on home and library index pages, listeners visiting an Album detail page, an Artist discography page, or a Discovery Mix detail page currently do not have a prominent, accessible "Add to playlist" action in the detail header. Furthermore, adding an entire artist discography or a whole generated mix to a playlist is currently impossible.

### User Persona & User Journey
- **Target Persona:** Deep Catalog Listener & Playlist Builder — A listener who wants to create comprehensive playlists like "Complete Radiohead", an album compilation, or preserve an algorithmic weekly mix before it changes.
- **Primary User Journey:**
  1. The listener visits an Artist page, an Album page, or a Mix page.
  2. In the hero section / header action bar, they see an option to "Add to playlist" (or open the hero options menu).
  3. They select "Add to playlist" (or "Add discography to playlist" on an artist page).
  4. The playlist picker modal opens, displaying all target playlists and the ability to create a new one. For a mix, the new playlist title is pre-filled with the mix's title.
  5. The listener picks an existing playlist or taps "Create" on the new playlist name.
  6. The interface indicates that the collection is being added and confirms completion with an informative feedback toast (e.g. *"Album added to playlist"*, *"Mix added to playlist"*, or *"Artist discography added to playlist"*).

### Success Metrics
- Full albums, artist discographies, and mixes can each be added to an existing or new playlist in a single workflow.
- Clear batch feedback communicating the addition of larger collections without locking up the user interface.

---

## 2. Functional Requirements & Scope

### In-Scope Functional Capabilities
- **FR-1 (Album Detail Hero):** The header of an album page must provide an "Add to playlist" option that queues the full album tracklist into the chosen playlist.
- **FR-2 (Mix Detail Hero):** The header of a Recommendation Collection (mix) page must provide an "Add to playlist" option that saves the entire mix tracklist into the chosen playlist.
- **FR-3 (Artist Detail Hero):** The options menu (`...`) on an artist page must provide an "Add discography to playlist" option that collects all catalog tracks by that artist and adds them into the chosen playlist.
- **FR-4 (Mix Pre-Population):** When opening the playlist picker for a Recommendation Collection (mix), the "New playlist name" input must be automatically pre-populated with the mix title (e.g. *"Friday Rediscovery"*), enabling a seamless 1-tap save into a dedicated playlist.
- **FR-5 (Unified Playlist Picker Modal):** Uses the exact same consistent playlist picker sheet as single tracks, supporting existing playlist selection and new playlist naming.
- **FR-6 (Batch Progress & Feedback):** When a batch addition (especially an entire artist discography) is initiated, the system displays a transient loading indicator, followed by a clear confirmation toast once finished.
- **FR-7 (Playback Uninterrupted):** Adding bulk collections to a playlist never interrupts active music playback.

### Edge Cases & Handling
- **EC-1 (Large Discographies):** For artists with hundreds of tracks, the addition process must show a polite loading state (e.g. *"Adding discography to playlist…"*) so the user knows work is in progress.
- **EC-2 (Partial Server Failure):** If an upstream server experiences a partial timeout during bulk addition, an informative error message is displayed (e.g. *"Couldn’t add full discography right now"*).
- **EC-3 (Duplicate Handling in Bulk):** If some tracks from the album or artist are already present in the playlist, the server appends the new items according to server rules without failing the entire batch.

### Explicit Out-of-Scope (Non-Goals)
- Selecting which specific albums to include when adding an artist's discography (this is an all-or-nothing discography action).
- Editing or renaming playlists from within the detail heroes.

---

## 3. User Experience & Behavioral Expectations

### 3.1 Interaction Model & Screen States
- **Discovery & Placement:**
  - *Album Detail Hero:* Located inside the hero options menu (`...`) or action bar.
  - *Artist Detail Hero:* Located inside the artist options menu (`...`) to prevent accidental massive additions while keeping it easily discoverable.
  - *Mix Detail Hero:* Located in the action bar or hero menu alongside "Play" and "Add to queue".
- **Interaction Flow:**
  1. User clicks "Add to playlist" (or "Add discography to playlist").
  2. Dialog opens displaying existing playlists and "New playlist" field (pre-filled if triggered from a mix).
  3. User selects or creates a playlist.
  4. Subtle modal spinner/loader appears: *"Adding items to playlist…"*.
  5. Dialog closes and toast appears: *"Album added to playlist"* / *"Mix added to playlist"* / *"Discography added to playlist"*.

### 3.2 Responsive & Multi-Device Behavior
- On desktop viewports, actions remain accessible via hero buttons or dropdown panels.
- On mobile viewports, the playlist picker opens as an ergonomic bottom sheet adhering to safe-area insets.

---

## 4. Open Questions & Advisor Consultation

*(All open questions have been resolved and moved to the Resolved Decisions Log below.)*

---

## 5. Resolved Decisions Log

### Decision 1: Artist Discography Action Placement & Prominence
- **Resolved Date:** 2026-10-10
- **Selected Option:** Place "Add discography to playlist" inside the artist page options menu (`...`), preventing accidental mass additions while keeping it easily discoverable.
- **Rationale & Advisor Alignment:** Adding a full discography is a significant bulk operation that can add hundreds of songs. Placing it in the secondary options menu prevents accidental taps while preserving clean visual hierarchy.
- **Impact on Requirements:** Formalized in FR-3 and Section 3.1.

### Decision 2: Mix / Recommendation Collection Save Behavior
- **Resolved Date:** 2026-10-10
- **Selected Option:** Pre-populate the new playlist name input with the mix title (e.g. *"Friday Rediscovery"*), allowing a 1-tap save into a new dedicated playlist or selection of an existing playlist.
- **Rationale & Advisor Alignment:** Greatly enhances UX speed by enabling users to preserve dynamic mixes before they rotate with minimal friction.
- **Impact on Requirements:** Formalized in FR-4.

---

## 6. Implementation Confidence Assessment

| Confidence Dimension | Weight | Current Score | Notes |
|---|---|---|---|
| **Domain & User Journey Clarity** | 25% | 25% | Album, artist, and mix bulk-save user journeys clearly defined. |
| **Functional Requirements & Edge Cases** | 25% | 25% | Requirements FR-1 through FR-7 and edge cases EC-1 through EC-3 specified. |
| **UX Behavior & Ergonomic Expectations** | 25% | 25% | Detail hero menus, pre-filled dialog inputs, and mobile bottom sheet behavior established. |
| **Unresolved Ambiguities (Open Questions)** | 25% | 25% | 0 open questions remaining (all reconciled in Decisions Log). |
| **Total Confidence Score** | **100%** | **100%** | **Status: Approved (Ready for Implementation)** |

> **Threshold to Proceed:** Implementation may begin only when **0 open questions remain** and the **Confidence Score is > 90%**.
