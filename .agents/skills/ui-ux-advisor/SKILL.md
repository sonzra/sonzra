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

## Review Workflow

1. **Inspect Frontend Code Changes**:
   ```bash
   git diff main...HEAD -- 'app/views' 'app/assets/stylesheets' 'app/javascript'
   ```
2. **Audit Against Invariants**: Run through the checklist above.
3. **Run Automated JavaScript / CSS Quality Checks**:
   ```bash
   npm run test:javascript
   bundle exec rubocop
   ```
4. **Deliver Structured Review**:
   - **Verdict**: `APPROVED`, `APPROVED WITH SUGGESTIONS`, or `CHANGES REQUESTED`
   - **Checklist**: Mark compliance across all UI/UX categories
   - **Findings**: Detail visual, responsive, or ergonomic flaws with file and line references
   - **Recommendations**: Provide concrete code snippets (CSS, ERB, JS) demonstrating the fix
