# Sonzra Design System (New Design)

This document establishes the canonical design system specification for Sonzra's modern interface (`ui_variant: "redesign"`). All new views, components, and interactive surfaces must strictly follow these tokens, layout rules, and component patterns.

> [!NOTE]
> This guide is also maintained at the root of the repository as [`DESIGN_SYSTEM.md`](../../DESIGN_SYSTEM.md).

---

## 1. Core Principles

1. **Quiet Listening Room:** Interface chrome yields prominence to album art and typography. Surfaces rest on atmospheric deep-space backgrounds (`#09090F`, `#12121C`) accented with subtle cyan and purple glows.
2. **Unified Geometric Rhythm:** Consistent sizing scales: 34px circular corner actions, 48px baseline form inputs, 14px/18px/22px container radii.
3. **Touch-First Ergonomics:** All tappable surfaces provide `>=44px` touch hitboxes. Compact visible controls use invisible `::before` expansions (`inset: -5px`) rather than visual bloat.
4. **Media-First Simplicity:** Avoid redundant visual indicators. Interactive cards with hover lifts do not need directional arrow glyphs (`arrow-up-right`), reserving corner space for primary actions.
5. **Hotwire Playback Continuity:** Audio playback is never interrupted by navigation (`data-turbo-permanent`). Corner actions update the DOM optimistically via Turbo Streams and audio feedback toasts without full-page reloads.

---

## 2. Design Tokens

All redesign styling is scoped under the `.redesign` class on the `<body>` element.

### Color Palette

```css
.redesign {
  --rz-primary: #7a5af8;       /* Primary brand purple */
  --rz-primary-light: #9b82ff; /* Focus rings, highlights, section kickers */
  --rz-primary-dark: #5c3fd6;  /* Gradients, pressed button states */
  --rz-accent: #43d7c6;        /* Equalizer bars, live state, connection dot */
  --rz-background: #09090f;    /* Deep space black canvas */
  --rz-surface: #12121c;       /* Navigation bars, secondary panels */
  --rz-raised: #191927;        /* Cards, sheets, popovers */
  --rz-hover: #232334;         /* Hover state for interactive items */
  --rz-text: #f6f6fa;          /* High-contrast typography */
  --rz-muted: #9694a6;         /* Secondary labels, metadata, artist subtitles */
  --rz-line: rgb(255 255 255 / 9%); /* Subtle hairline border */
  --rz-radius: 18px;           /* Standard container corner radius */
}
```

### Elevation & Borders
- **Hairlines:** Prefer `1px solid var(--rz-line)` or `1px solid rgb(255 255 255 / 12%)`.
- **Gradients:** Glassmorphic surfaces use subtle angled gradients:
  `background: linear-gradient(145deg, rgb(255 255 255 / 5%), rgb(255 255 255 / 2%));`
- **Shadows:** Floating panels, sheets, and persistent players use deep blurred drop shadows:
  `box-shadow: 0 18px 48px rgb(0 0 0 / 28%);`

### Typography Hierarchy
- **Font Stack:** `Manrope`, `Inter`, `system-ui`, `sans-serif`.
- **Eyebrow / Kicker:** `font-size: 10px; font-weight: 800; letter-spacing: .14em; text-transform: uppercase; color: var(--rz-primary-light);`
- **Page Titles:** `font-size: clamp(30px, 4.5vw, 44px); letter-spacing: -.05em; font-weight: 800; line-height: 1;`
- **Section Headings:** `font-size: 25px; letter-spacing: -.04em; font-weight: 800;`
- **Card Titles:** `font-size: 15px; font-weight: 800; color: #fff;` (discovery tiles) or `font-size: 13px; font-weight: 700;` (mix/album cards).
- **Tabular Numerics:** All track timers, durations, and counts must use `font-variant-numeric: tabular-nums;`.

---

## 3. Component Specifications

### 1. Corner Action Badges (`.listen-card__options-toggle`, `.genre-tile__hide-button`)
Standardized circular button used for secondary corner interactions on cards and exploration tiles.

```css
.corner-action-badge {
  position: absolute;
  top: 10px;
  right: 10px;
  z-index: 2;
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  min-width: 34px;
  min-height: 34px;
  padding: 0;
  margin: 0;
  border: 1px solid var(--rz-line);
  border-radius: 50%;
  background: rgb(9 9 15 / 80%);
  color: var(--rz-text);
  backdrop-filter: blur(8px);
  cursor: pointer;
  transition: border-color .18s ease, background .18s ease, transform .18s ease;
}

/* Invisible 44px touch hitbox expansion */
.corner-action-badge::before {
  content: "";
  position: absolute;
  inset: -5px; /* 34px + 10px = 44px tap target */
}

.corner-action-badge svg {
  display: block;
  width: 15px;
  height: 15px;
  margin: 0;
  pointer-events: none;
}
```

*Implementation rule:* When wrapping in Rails `button_to`, apply `display: contents;` to the enclosing form so CSS Grid/Flex alignment and absolute placement bind directly to the button element.

### 2. Form System (`.form-page--compact`, `.connection-form`)
Forms for settings, preferences, and utilities follow a compact, baseline-aligned grid layout.

- **Container:** Glassmorphic card (`.form-page--compact`) with `padding: 20px 24px` on desktop and `16px` on mobile.
- **Controls Height:** Inputs (`.field input`), selects (`.field select`), and submit buttons (`.primary-button`) share a strict **48px baseline height**.
- **Desktop Grid:**
  ```css
  .connection-form {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: end;
    gap: 14px;
    width: 100%;
  }
  ```
- **Mobile Grid:** Stacks vertically with `gap: 10px;` and full-width buttons.

### 3. Discovery Tiles (`.genre-tile`, `.redesign-genre-tile`)
Bold, typography-first interactive cards used for browsing categories, moods, and genres.

- **Aspect Ratio:** Fixed height on home (`min-height: 86px;`) or 1:1 square in full directories (`aspect-ratio: 1;`).
- **Typography:** Genre name anchored at the bottom-left (`align-items: end;`).
- **No Redundant Glyphs:** Interactive tiles with hover lifts **do not include directional arrow glyphs** (`arrow-up-right`), reserving the top-right corner exclusively for the 34px action badge.
- **Hover Lift:** `transform: translateY(-3px); border-color: rgb(155 130 255 / 55%);`.

### 4. Compact Row Cards (`.connection-card`)
Used in settings lists, hidden item managers, and server lists.

- **Desktop:** Compact horizontal row with `min-height: 64px`, `padding: 14px 20px`, and `border-radius: 14px`.
- **Mobile:** Retains horizontal row layout (`flex-direction: row; justify-content: space-between; align-items: center;`) with `min-height: 56px`, preventing bloated vertical stacking.
- **Action Button:** Hairline secondary button with `min-height: 38px` (desktop) and `min-height: 44px` (mobile).

### 5. Utility Page Shell (`.redesign-utility-page`)
Dedicated layout shell for settings, account management, and utility flows.

- **Content Width:** Capped at `min(100%, 1060px); margin: 0 auto;`.
- **Vertical Spacing:**
  - Desktop: `padding-top: 36px;`
  - Mobile: `padding-top: 16px;`
- **Header:** Sticky or static header with compact back button (38×38px) and border divider (`padding-bottom: 16px; margin-bottom: 22px;`).

### 6. Feedback & Notification Toasts (`.listen-player__feedback`)
Transient feedback alerts for async operations (e.g. "Hidden Ambient from mixes", "Added to favorites").

- Fixed floating pill docked below the top navigation bar.
- Border radius: `999px` fully rounded pill.
- Background: `rgb(24 20 42 / 95%)` with cyan/purple border glow.
- Accessible ARIA live region (`role="status" aria-live="polite"`).
- Hotwire integration: Rendered via Turbo Streams to update `#player_feedback` without page refreshes.

---

## 4. Responsive Viewport Tiers

| Tier | Breakpoint | Layout Adaptations |
|---|---|---|
| **Desktop** | `> 980px` | 5-column shelves, 3-column floating player, 20–24px card padding, popover context menus |
| **Tablet** | `701px – 980px` | 4-column shelves, collapsed player utilities, modal dialogs |
| **Mobile** | `<= 700px` | Swipeable horizontal carousels (`142px` cards), compact 67px mini-player, 16px form padding, bottom sheets |

---

## 5. UI/UX Invariants Checklist

When building new features under the Redesign system, verify:

- [ ] All colors reference `--rz-*` tokens; zero raw color literals.
- [ ] Circular corner action badges use `34px × 34px` with `::before { inset: -5px; }` for 44px touch compliance.
- [ ] Action badge icons are perfectly centered (`offset: 0px`).
- [ ] Form inputs and submit buttons share a `48px` baseline height.
- [ ] Safe-area insets (`env(safe-area-inset-*)`) are present on all edge-anchored elements.
- [ ] No redundant directional arrows on interactive discovery tiles.
- [ ] List items maintain compact horizontal rows on mobile rather than needlessly stacking vertically.
- [ ] Async interactions provide optimistic DOM updates and toast feedback without page reloads.
- [ ] High-contrast focus rings (`outline: 2px solid var(--rz-primary-light); outline-offset: 3px;`) are preserved.
