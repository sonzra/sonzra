---
name: ui-ux-advisor
description: >-
  UI and UX advisor for analyzing frontend code changes, view templates, CSS stylesheets,
  Stimulus controllers, and design proposals against Sonzra's UI and UX guidelines (docs/guidelines/ui_ux.md,
  docs/BRAND.md, and docs/CONTEXT.md). Use this skill whenever reviewing interface changes,
  validating responsive layouts, checking touch target ergonomics (>=44px), verifying safe-area insets,
  ensuring persistent player continuity, and auditing accessibility or reduced-motion compliance.
---

# Sonzra UI & UX Advisor

The UI & UX Advisor evaluates frontend code changes, visual designs, and interaction patterns against Sonzra's official UI and UX guidelines.

## Reference Documents

- [UI & UX Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/ui_ux.md)
- [Architectural Guidelines](file:///home/bruno/Projects/sonzra/docs/guidelines/architecture.md)
- [Brand System](file:///home/bruno/Projects/sonzra/docs/BRAND.md)
- [Context & Vision](file:///home/bruno/Projects/sonzra/docs/CONTEXT.md)
- [Engineering Principles (Responsive UX)](file:///home/bruno/Projects/sonzra/docs/ENGINEERING.md#L61-L76)

## Core UI/UX Invariants to Verify

### 1. Visual Hierarchy & Design Tokens
- **"Quiet Listening Room" Aesthetic**: Ensure high contrast for album art and typography, with interface chrome resting on neutral near-black backgrounds (`#09090F`, `#12121C`).
- **Token Compliance**: Verify all styles use the `--rz-*` custom properties rather than hardcoded hex values or arbitrary color literals.
- **Typography & Timers**: Ensure `Manrope` / `Inter` font stack. Verify `font-variant-numeric: tabular-nums` on track durations and playback elapsed times.

### 2. Persistent Playback Continuity
- **Uninterrupted Audio**: The player container (`#player`), queue (`#player-queue`), and feedback alerts (`#player-feedback`) must retain `data-turbo-permanent`.
- **Dual Breakpoint Layouts**:
  - **Desktop (>980px)**: 3-column floating glass card (Identity, Transport/Timeline, Volume/Actions).
  - **Mobile (<=700px)**: Compact 67px mini-player docked immediately above the bottom navigation bar.
- **Visualizer Activity**: The playback equalizer mark must animate only when `is-playing` is active, and must yield to reactive audio levels when available.

### 3. Responsive Layouts & Breakpoints
- **Layout Tiers**: Verify layouts at `375px` (mobile), `768px` (tablet), and `1440px` (desktop).
- **Shelves vs. Grids**: Curated home shelves must render as 5-column grids on desktop and swipeable horizontal carousels with `scroll-snap-type: x proximity` on mobile.
- **Safe-Area Insets**: All fixed or edge-anchored elements must incorporate `env(safe-area-inset-top)` and `env(safe-area-inset-bottom)`.
- **Zero Horizontal Page Overflow**: Ensure text wraps cleanly and flex/grid items have `min-width: 0` to prevent horizontal viewport blowout.

### 4. Touch Targets & Progressive Disclosure
- **Minimum 44px Touch Target**: Every tappable control on mobile must provide a `44x44px` minimum bounding box.
- **No Hover Exclusivity**: Secondary actions (favorites, playlist additions, offline downloads, card options) must not rely solely on desktop `:hover`. They must be accessible via direct controls, bottom sheets, or the 550ms long-press gesture.
- **Desktop Popovers vs. Mobile Sheets**: Context menus must open as anchored popovers on desktop and sliding bottom sheets on mobile.

### 5. Motion, Loading States & Reduced Motion
- **Branded Transition Loader**: Full-page loader must obey the 180ms debounce delay and 350ms minimum display time.
- **Strict Reduced-Motion**: Under `@media (prefers-reduced-motion: reduce)`, verify that orbital rotations, breathing glows, equalizer animations, and translation offsets are disabled.

### 6. Accessibility (a11y) & Ergonomics
- **Focus Rings**: Ensure `:focus-visible` outlines (`outline: 2px solid var(--rz-primary-light); outline-offset: 3px`) are never suppressed.
- **ARIA Context**: Icon-only buttons must carry descriptive `aria-label`s; decorative SVGs must have `aria-hidden="true"`.
- **Dynamic Notifications**: Transient alerts must use ARIA live regions (`role="status" aria-live="polite"`).

### 7. Redesign Theme Self-Sufficiency & Dialog Standards
- **Single-Stylesheet Invariant**: When `redesign_enabled?` is active, `redesign.css` is the *only* stylesheet loaded. Styles must **never** inherit from or assume the presence of classes in classic stylesheets (`queue.css`, `application.css`, etc.).
- **Canonical Dialog Architecture**: All `<dialog>` elements must reset native user-agent chrome and follow the `.redesign-*-dialog` pattern:
  - Container: `border: 1px solid var(--rz-line); border-radius: 22px; background: rgb(18 18 28 / 98%); box-shadow: 0 30px 100px rgb(0 0 0 / 75%); backdrop-filter: blur(20px); overflow: hidden;`
  - Backdrop: `background: rgb(0 0 0 / 72%); backdrop-filter: blur(8px);`
  - Header: Uppercase `--rz-primary-light` kicker, bold 22px title with explicit `--rz-text`, and a dedicated 34x34px circular close button (`X`).
  - Typography: Never leave headings or descriptions un-themed to prevent browser default black text on dark surfaces.

### 8. Mobile Geometry & Pixel Budget Invariant
- **Pixel Budgeting**: For mobile viewports ($\le 430\text{px}$), never place more than 2 secondary controls in the same row as artwork and track titles.
- **3-Row Player Card Layout**: Mobile player drawers must stack playback elements:
  - **Row 1 (Identity)**: Artwork (56x56px) + Track title and artist (usable width $\ge 180\text{px}$, clean single-line ellipsis truncation).
  - **Row 2 (Scrubber)**: Full-width timeline slider with tabular timestamps.
  - **Row 3 (Transport)**: Dedicated flex row with evenly spaced buttons, 100% contained within the card with zero edge overflow.
- **Control Deduplication**: Never duplicate action toggles on the same view (e.g., shuffle or radio in both the transport card and the queue header).

### 9. Multimodal Visual Verification (Mandatory Inspection)
- **Beyond Unit Tests**: Automated tests (Vitest, minitest) only verify DOM existence and event logic; they do not calculate CSS box models, bounding boxes, or visual clipping.
- **Mandatory Visual Inspection**: For any frontend modification, capture screenshots under desktop (`1440x900`) and mobile (`390x844`) viewports and inspect each image file directly:
  1. **Container Containment**: No controls clipped or overflowing container edges.
  2. **Text Legibility**: Track title and artist easily readable with zero micro-squeezing.
  3. **Theme Integrity**: No browser-default white dialog borders or un-styled buttons.
  4. **Clean Segregation**: No duplicate toggles across adjacent surfaces.

## Review Workflow

1. **Inspect Frontend Code Changes**:
   ```bash
   git diff main...HEAD -- 'app/views' 'app/assets/stylesheets' 'app/javascript'
   ```
2. **Audit Against Invariants**: Run through the checklist above (including Sections 7–9).
3. **Capture and Inspect Screenshots**:
   - Run headless browser capture on desktop (`1440x900`) and mobile (`390x844`).
   - Visually inspect screenshots with image tools before signing off.
4. **Run Automated JavaScript / CSS Quality Checks**:
   ```bash
   npm run test:javascript
   bundle exec rubocop
   ```
5. **Deliver Structured Review**:
   - **Verdict**: `APPROVED`, `APPROVED WITH SUGGESTIONS`, or `CHANGES REQUESTED`
   - **Checklist**: Mark compliance across all UI/UX categories
   - **Findings**: Detail visual, responsive, or ergonomic flaws with file and line references
   - **Recommendations**: Provide concrete code snippets (CSS, ERB, JS) demonstrating the fix
